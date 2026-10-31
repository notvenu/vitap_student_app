import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/error_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/constants/analytics_constants.dart';
import 'package:vit_ap_student_app/core/models/timetable.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/analytics_service.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/academic_calendar/utils/class_days.dart';
import 'package:vit_ap_student_app/features/academic_calendar/view/pages/academic_calendar_page.dart';
import 'package:vit_ap_student_app/features/academic_calendar/viewmodel/cached_calendar_provider.dart';
import 'package:vit_ap_student_app/features/timetable/utils/dated_classes.dart';
import 'package:vit_ap_student_app/features/timetable/view/widgets/schedule_list.dart';
import 'package:vit_ap_student_app/features/timetable/viewmodel/timetable_viewmodel.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  /// Weeks away from this one: 0 is now, -1 last week, 1 next.
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    final int currentDayIndex = DateTime.now().weekday % 7;
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: currentDayIndex,
    );

    // Analytics tracking
    ref.read(analyticsServiceProvider).logScreen('TimetablePage');
    // Track tab changes for analytics
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        ref.read(analyticsServiceProvider).logEvent(
          AnalyticsEvents.timetableDayChanged,
          {AnalyticsParams.dayIndex: _tabController.index},
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _todaySummary(Timetable? timetable, Map<String, NoClassDay> noClass) {
    final DateTime today = DateTime.now();
    final NoClassDay? off = noClass[isoDate(today)];
    if (off != null) return 'No classes today · ${off.reason}';

    final int count = timetable == null
        ? 0
        : classesOn(timetable, today).length;
    return count == 0 ? 'No classes today' : 'You have $count classes Today';
  }

  /// `1 – 7 Nov`, `29 Nov – 5 Dec`, with the year only when it isn't this one.
  String _weekRange(List<DateTime> week) {
    final DateTime first = week.first;
    final DateTime last = week.last;
    final String year = last.year == DateTime.now().year ? '' : ' ${last.year}';
    return first.month == last.month
        ? '${first.day} – ${DateFormat('d MMM').format(last)}$year'
        : '${DateFormat('d MMM').format(first)} – '
              '${DateFormat('d MMM').format(last)}$year';
  }

  Future<void> _openAcademicCalendar() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AcademicCalendarPage()),
    );
    // A calendar loaded there should show here straight away.
    ref.invalidate(cachedCalendarProvider);
  }

  Future<void> refresh() async {
    ref.read(analyticsServiceProvider).logEvent(
      AnalyticsEvents.refreshInitiated,
      {AnalyticsParams.dataType: 'timetable'},
    );
    await ref.read(timetableViewModelProvider.notifier).refreshTimetable();
  }

  Widget _buildTab({
    required String label,
    required DateTime date,
    required bool isToday,
    required bool isNoClassDay,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      height: 58,
      width: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? cs.primary : null,
            ),
          ),
          const SizedBox(height: 3),
          // Marks a holiday, exam or no-instruction day before it's opened.
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isNoClassDay ? cs.tertiary : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader(List<DateTime> week) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous week',
          onPressed: () => setState(() => _weekOffset--),
        ),
        Expanded(
          child: Text(
            _weekRange(week),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_weekOffset != 0)
          TextButton(
            onPressed: () => setState(() {
              _weekOffset = 0;
              _tabController.animateTo(DateTime.now().weekday % 7);
            }),
            child: const Text('Today'),
          ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next week',
          onPressed: () => setState(() => _weekOffset++),
        ),
      ],
    );
  }

  /// Shown until the academic calendar has been loaded once. Fetching it
  /// stays the student's call: it's a request per month, and VTOP can ask for
  /// an OTP.
  Widget _buildCalendarHint() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: Icon(Iconsax.calendar_1_copy, color: cs.onSurfaceVariant),
        title: const Text('Load the academic calendar to see holidays'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _openAcademicCalendar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final timetable = user?.timetable;

    final calendarState = ref.watch(cachedCalendarProvider);
    final Map<String, NoClassDay> noClass = noClassDays(calendarState.value);
    final bool calendarMissing =
        calendarState.hasValue && calendarState.value == null;

    final DateTime today = DateTime.now();
    final List<DateTime> week = weekOf(today, weekOffset: _weekOffset);

    final isLoading = ref.watch(
      timetableViewModelProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(timetableViewModelProvider, (_, next) {
      next?.when(
        data: (data) {},
        loading: () {},
        error: (error, st) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
      );
    });
    return Scaffold(
      body: user == null || timetable == null
          ? const ErrorContentView(error: 'User not found!')
          : RefreshIndicator(
              onRefresh: refresh,
              notificationPredicate: (notification) => notification.depth == 2,
              child: NestedScrollView(
                physics: const BouncingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      automaticallyImplyLeading: true,
                      expandedHeight: 75,
                      centerTitle: false,
                      actions: [
                        IconButton(
                          icon: Icon(
                            Iconsax.refresh_copy,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            refresh();
                          },
                          tooltip: 'Refresh',
                        ),
                      ],
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timetable',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _todaySummary(timetable.target, noClass),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          children: [
                            _buildWeekHeader(week),
                            if (calendarMissing) ...[
                              _buildCalendarHint(),
                              const SizedBox(height: 8),
                            ],
                            TabBar(
                              controller: _tabController,
                              isScrollable: false,
                              dividerColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              labelPadding: const EdgeInsets.all(0),
                              splashBorderRadius: BorderRadius.circular(14),
                              unselectedLabelColor: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              labelColor: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              indicator: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              splashFactory: InkRipple.splashFactory,
                              overlayColor: WidgetStateColor.resolveWith(
                                (states) => Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                              ),
                              tabs: [
                                for (int i = 0; i < 7; i++)
                                  _buildTab(
                                    label: const [
                                      'S',
                                      'M',
                                      'T',
                                      'W',
                                      'T',
                                      'F',
                                      'S',
                                    ][i],
                                    date: week[i],
                                    isToday: isoDate(week[i]) == isoDate(today),
                                    isNoClassDay: noClass.containsKey(
                                      isoDate(week[i]),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: isLoading
                    ? const Loader()
                    : TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          for (int i = 0; i < 7; i++)
                            ScheduleList(
                              day: weekdayName(week[i]),
                              noClassReason: noClass[isoDate(week[i])]?.reason,
                            ),
                        ],
                      ),
              ),
            ),
    );
  }
}
