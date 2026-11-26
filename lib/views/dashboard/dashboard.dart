import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'edit.dart';
import 'layout.dart';
import 'style.dart';
import 'widget_registry.dart';
import 'widgets/widgets.dart';

// Narrower columns leave a pair of service cells too tight for a status, so
// the grid stacks them in one.
const _servicePairColumnMin = 290.0;

const _maxColumnWidth = 440.0;

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key, this.platform});

  /// The host's platform when null.
  final SupportPlatform? platform;

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  var _editing = false;
  final _cardKeys = <DashboardWidget, GlobalKey>{};
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = sheetScrollController(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setEditing(bool editing) {
    setState(() => _editing = editing);
  }

  GlobalKey _cardKeyOf(DashboardWidget widget) =>
      _cardKeys.putIfAbsent(widget, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform ?? SupportPlatform.currentPlatform;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    final editing = _editing;
    final gap = cardSpacingOf(context, ref.watch(viewModeProvider));
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      backgroundColor: DashboardColors.of(context).page,
      title: editing
          ? appLocalizations.editDashboard
          : appLocalizations.dashboard,
      actions: [
        if (!editing) const LiveStatusButton(),
        if (!editing)
          AppBarActionButton(
            data: IconButtonData(
              glyph: AppGlyphs.edit,
              tooltip: appLocalizations.editDashboard,
              onPressed: () => _setEditing(true),
            ),
          ),
      ],
      confirmationAction: editing
          ? IconButtonData(
              glyph: AppGlyphs.check,
              tooltip: appLocalizations.done,
              onPressed: () => _setEditing(false),
            )
          : null,
      // The providers learn a resize a frame late, too late for the cards.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final room = constraints.biggest / scale;
          final layout = DashboardDensity.of(room);
          return DashboardDensityScope(
            density: layout,
            scale: scale,
            child: layout.isDesktop
                ? _DesktopDashboard(
                    platform: platform,
                    columns: dashboardColumnsOf(room.width),
                    gap: gap,
                    editing: editing,
                  )
                : _MobileDashboard(
                    controller: _controller,
                    platform: platform,
                    gap: gap,
                    editing: editing,
                    cardKeyOf: _cardKeyOf,
                    onDone: () => _setEditing(false),
                  ),
          );
        },
      ),
    );
  }
}

/// Four columns fill the window, the tables taking what the rows above them
/// leave. A window too short for the tables, and every two column one, gets
/// the summary cards instead, so no list scrolls inside a page that scrolls.
///
/// The saved cards decide what these rows hold; a card the editor hides lets
/// the rest of its row grow.
class _DesktopDashboard extends ConsumerWidget {
  const _DesktopDashboard({
    required this.platform,
    required this.columns,
    required this.gap,
    required this.editing,
  });

  final SupportPlatform platform;
  final int columns;
  final double gap;
  final bool editing;

  void _remove(WidgetRef ref, DashboardWidget widget) {
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            dashboardWidgets: [...state.dashboardWidgets]..remove(widget),
          ),
        );
  }

  void _add(WidgetRef ref, DashboardWidget widget) {
    ref.read(appSettingProvider.notifier).update((state) {
      if (state.dashboardWidgets.contains(widget)) return state;
      return state.copyWith(
        dashboardWidgets: [...state.dashboardWidgets, widget],
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = DashboardDensityScope.of(context);
    final compact = density.isCompact;
    final scale = DashboardDensityScope.scaleOf(context);
    final saved = ref.watch(
      dashboardStateProvider.select((state) => state.dashboardWidgets),
    );
    final shown = {
      for (final widget in saved)
        if (widget.platforms.contains(platform)) widget,
      DashboardWidget.currentOutbound,
    };
    final wifiHeight = wifiModeCardHeight(
      ref.watch(wifiModeSettingProvider.select((state) => state.rules.length)),
      scale,
    );
    final base = EdgeInsetsDirectional.fromSTEB(
      16,
      context.contentTopPadding,
      24,
      24 + MediaQuery.paddingOf(context).bottom,
    );
    final topHeight = (compact ? 176 : 208) * scale;
    final controlHeight = (compact ? 56 : 64) * scale;
    final middleHeight = (compact ? 152 : 176) * scale;
    final tablesHeight = connectionsTableMinHeight(density, scale);
    final summaryHeight = (compact ? 112 : 120) * scale;
    final top = [
      for (final widget in const [
        DashboardWidget.currentOutbound,
        DashboardWidget.networkSpeed,
      ])
        if (shown.contains(widget)) widget,
    ];
    final control = [
      for (final widget in const [
        DashboardWidget.outboundMode,
        DashboardWidget.systemProxy,
        DashboardWidget.tun,
        DashboardWidget.vpnButton,
      ])
        if (shown.contains(widget)) widget,
    ];
    final middle = [
      for (final widget in const [
        DashboardWidget.intranetIp,
        DashboardWidget.profiles,
        DashboardWidget.serviceStatus,
        DashboardWidget.memoryInfo,
      ])
        if (shown.contains(widget)) widget,
    ];
    final bottom = [
      for (final widget in const [
        DashboardWidget.connectionStats,
        DashboardWidget.proxyGroups,
      ])
        if (shown.contains(widget)) widget,
    ];
    final addable = [
      for (final widget in DashboardWidget.values)
        if (widget.platforms.contains(platform) && !shown.contains(widget))
          widget,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final room =
            constraints.maxWidth - base.horizontal - gap * (columns - 1);
        final column = math.min(room / columns, _maxColumnWidth * scale);
        final inset = (room - column * columns) / 2;
        final padding = base.copyWith(
          start: base.start + inset,
          end: base.end + inset,
        );
        final serviceColumns = column >= _servicePairColumnMin * scale ? 2 : 1;
        double span(int count) => column * count + gap * (count - 1);

        Widget barrier(Widget child) =>
            editing ? AbsorbPointer(child: child) : child;

        Widget removable(DashboardWidget widget, Widget child) {
          if (!editing || !widget.removable) {
            return barrier(child);
          }
          return Stack(
            fit: StackFit.passthrough,
            children: [
              barrier(child),
              PositionedDirectional(
                top: 0,
                end: 0,
                child: DashboardRemoveButton(
                  label: widget.label(context),
                  onPressed: () => _remove(ref, widget),
                ),
              ),
            ],
          );
        }

        (int, Widget) cellOf(DashboardWidget widget) => switch (widget) {
          DashboardWidget.currentOutbound => (2, const CurrentOutboundCard()),
          DashboardWidget.networkSpeed => (
            2,
            Row(
              spacing: gap,
              children: const [
                Expanded(child: SpeedCard(direction: TrafficDirection.upload)),
                Expanded(
                  child: SpeedCard(direction: TrafficDirection.download),
                ),
              ],
            ),
          ),
          DashboardWidget.outboundMode => (2, const OutboundModeBar()),
          DashboardWidget.vpnButton => (2, const VpnTile()),
          DashboardWidget.systemProxy => (
            1,
            const NetworkTakeoverTile(TakeoverSwitch.systemProxy),
          ),
          DashboardWidget.tun => (
            1,
            const NetworkTakeoverTile(TakeoverSwitch.tun),
          ),
          DashboardWidget.intranetIp => (1, const IntranetIpCard()),
          DashboardWidget.profiles => (1, const ProfilesCard()),
          DashboardWidget.serviceStatus => (
            1,
            ServiceStatusCard(columns: serviceColumns),
          ),
          DashboardWidget.memoryInfo => (1, const MemoryInfo()),
          DashboardWidget.wifiMode ||
          DashboardWidget.connectionStats ||
          DashboardWidget.proxyGroups => throw ArgumentError.value(
            widget,
            'widget',
            'takes a row of its own',
          ),
        };

        void packRows(
          double height,
          List<DashboardWidget> widgets,
          List<double> heights,
          List<Widget> into,
        ) {
          var cells = <(int, Widget)>[];
          var used = 0;
          void flush() {
            if (cells.isEmpty) return;
            into.add(
              SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [
                    for (var index = 0; index < cells.length; index++)
                      if (index == cells.length - 1 && used < columns)
                        Expanded(child: RepaintBoundary(child: cells[index].$2))
                      else
                        SizedBox(
                          width: span(cells[index].$1),
                          child: RepaintBoundary(child: cells[index].$2),
                        ),
                  ],
                ),
              ),
            );
            heights.add(height);
            cells = [];
            used = 0;
          }

          for (final widget in widgets) {
            final (flex, child) = cellOf(widget);
            if (used + flex > columns && cells.isNotEmpty) {
              flush();
            }
            cells.add((flex, removable(widget, child)));
            used += flex;
          }
          flush();
        }

        Widget bottomCard(
          DashboardWidget widget, {
          required bool table,
        }) => switch (widget) {
          DashboardWidget.connectionStats =>
            table ? const ConnectionsTableCard() : const ConnectionStatsCard(),
          DashboardWidget.proxyGroups =>
            table ? const ProxyGroupsCard() : const ProxyGroupsSummaryCard(),
          _ => throw ArgumentError.value(widget, 'widget', 'is not a summary'),
        };

        final rowHeights = <double>[];
        final rows = <Widget>[];
        packRows(topHeight, top, rowHeights, rows);
        packRows(controlHeight, control, rowHeights, rows);
        packRows(middleHeight, middle, rowHeights, rows);
        if (shown.contains(DashboardWidget.wifiMode)) {
          rows.add(
            SizedBox(
              height: wifiHeight,
              child: RepaintBoundary(
                child: removable(
                  DashboardWidget.wifiMode,
                  const WifiModeCard(),
                ),
              ),
            ),
          );
          rowHeights.add(wifiHeight);
        }

        Widget bottomRow({required bool table}) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            for (final widget in bottom)
              Expanded(
                flex: !table
                    ? 1
                    : widget == DashboardWidget.connectionStats
                    ? 3
                    : 2,
                child: RepaintBoundary(
                  child: removable(widget, bottomCard(widget, table: table)),
                ),
              ),
          ],
        );
        final rowsHeight =
            padding.vertical +
            rowHeights.fold(0.0, (sum, height) => sum + height) +
            gap * (rows.length - 1);
        final canFill = !(editing && addable.isNotEmpty);
        final tablesFit =
            columns == 4 &&
            bottom.isNotEmpty &&
            constraints.maxHeight >= rowsHeight + gap + tablesHeight;
        final fills =
            canFill &&
            constraints.maxHeight >=
                rowsHeight + gap + (bottom.isEmpty ? 0 : summaryHeight);
        final Widget? bottomWidget = bottom.isEmpty
            ? null
            : tablesFit
            ? canFill
                  ? Expanded(child: bottomRow(table: true))
                  : SizedBox(
                      height: tablesHeight,
                      child: bottomRow(table: true),
                    )
            : fills
            ? Expanded(child: bottomRow(table: false))
            : SizedBox(height: summaryHeight, child: bottomRow(table: false));
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: fills ? constraints.maxHeight : null,
            child: Padding(
              padding: padding,
              child: Column(
                spacing: gap,
                children: [
                  ...rows,
                  ?bottomWidget,
                  if (editing && addable.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DashboardSectionLabel(
                      context.appLocalizations.dashboardAddableSection,
                    ),
                    for (final widget in addable) ...[
                      DashboardAddRow(
                        item: widget,
                        onAdd: () => _add(ref, widget),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileDashboard extends ConsumerWidget {
  const _MobileDashboard({
    required this.controller,
    required this.platform,
    required this.gap,
    required this.editing,
    required this.cardKeyOf,
    required this.onDone,
  });

  final ScrollController controller;
  final SupportPlatform platform;
  final double gap;
  final bool editing;
  final GlobalKey Function(DashboardWidget widget) cardKeyOf;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      dashboardStateProvider.select((state) => state.dashboardWidgets),
    );
    final top = context.contentTopPadding;
    final bottom = 16 + context.bottomInset;
    return CustomScrollView(
      controller: controller,
      // A viewport per card lays them all out and holds the scroll end still.
      scrollCacheExtent: editing
          ? ScrollCacheExtent.viewport(DashboardWidget.values.length.toDouble())
          : null,
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final side = dashboardMobileSideOf(constraints.crossAxisExtent);
            final widgets = [
              for (final widget in saved)
                if (widget.platforms.contains(platform)) widget,
            ];
            if (editing) {
              return DashboardEditor(
                platform: platform,
                widgets: widgets,
                cardKeyOf: cardKeyOf,
                padding: EdgeInsets.fromLTRB(side, top, side, bottom),
                gap: gap,
                onDone: onDone,
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(side, top, side, bottom),
              // A lazy list estimates the cards it has not laid out from the
              // ones it has; cards this uneven move the scroll end as it goes.
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [
                    for (final widget in widgets)
                      RepaintBoundary(
                        key: cardKeyOf(widget),
                        child: widget.card,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
