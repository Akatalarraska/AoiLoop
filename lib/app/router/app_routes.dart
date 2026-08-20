/// Every navigable location in AoiLoop, in one place.
///
/// Navigate by name (`context.goNamed(AppRoute.calendar.routeName)`) so paths
/// can change without a search-and-replace across features.
///
/// The field is called `routeName` rather than `name` because Dart reserves
/// `name` on enums.
enum AppRoute {
  // --- Entry points -------------------------------------------------------
  /// Shown while the app reads the profile and decides where to send the user.
  startup('/startup', 'startup'),

  /// The first-run flow. Reachable only while no profile exists.
  onboarding('/onboarding', 'onboarding'),

  // --- Primary destinations (bottom navigation) ---------------------------
  dashboard('/', 'dashboard'),
  calendar('/calendar', 'calendar'),
  bodyMap('/body', 'body-map'),
  history('/history', 'history'),

  // --- Secondary destinations (pushed over the shell) --------------------
  inventory('/inventory', 'inventory'),
  travel('/travel', 'travel'),
  family('/family', 'family'),
  settings('/settings', 'settings');

  const AppRoute(this.path, this.routeName);

  /// Location pattern used by GoRouter.
  final String path;

  /// Stable identifier used for name-based navigation.
  final String routeName;
}
