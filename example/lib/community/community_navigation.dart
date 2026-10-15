/// The sample's persistent Community presentation preference.
enum CommunityNavigation {
  inTab('In tab'),
  fullScreen('Full screen');

  const CommunityNavigation(this.label);
  final String label;
}

const communityNavigationPreferenceKey = 'community_navigation_v1';
