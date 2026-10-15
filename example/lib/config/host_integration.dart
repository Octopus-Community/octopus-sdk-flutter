enum HostUrlHandling {
  sampleRule('Sample rule (unavailable)'),
  inApp('Always open in the app'),
  sdk('Always let Octopus open');

  const HostUrlHandling(this.label);
  final String label;
}
