/// Filter applied to the channel list.
///
/// The special views (favorites, recent) live next to the plain
/// subscription groups in the group chip row.
sealed class ChannelFilter {
  /// Creates the filter.
  const ChannelFilter();
}

/// Shows all channels of all subscriptions.
final class FilterAll extends ChannelFilter {
  /// Creates the filter.
  const FilterAll();
}

/// Shows only channels marked as favorite.
final class FilterFavorites extends ChannelFilter {
  /// Creates the filter.
  const FilterFavorites();
}

/// Shows recently watched channels, latest first.
final class FilterRecent extends ChannelFilter {
  /// Creates the filter.
  const FilterRecent();
}

/// Shows channels of one playlist group.
final class FilterGroup extends ChannelFilter {
  /// Creates the filter.
  const FilterGroup(this.group);

  /// The group title to match (ungrouped channels use the shared
  /// ungrouped label).
  final String group;
}

/// Shows channels whose name contains [query] (case-insensitive).
final class FilterSearch extends ChannelFilter {
  /// Creates the filter.
  const FilterSearch(this.query);

  /// The search query; an empty query matches every channel.
  final String query;
}

/// Shows only channels whose latest probe result is `ProbeStatus.ok`.
final class FilterAvailable extends ChannelFilter {
  /// Creates the filter.
  const FilterAvailable();
}
