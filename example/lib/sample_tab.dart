/// Canonical order shared by the shell and all navigation requests.
enum SampleTab {
  scenarios('Scenarios'),
  community('Community'),
  settings('Settings');

  const SampleTab(this.label);
  final String label;
}
