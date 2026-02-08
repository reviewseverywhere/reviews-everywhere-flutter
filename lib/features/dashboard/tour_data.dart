class TourStep {
  final String title;
  final String body;

  const TourStep({required this.title, required this.body});
}

const List<TourStep> dashboardTourSteps = [
  TourStep(
    title: 'Welcome to Reviews Everywhere!',
    body:
        "Let's take a quick tour to see how you can get the most out of your dashboard. This is a live simulation of your first 21 days.",
  ),
  TourStep(
    title: 'Your Full-Access Period',
    body:
        'For the first 21 days, you have full access to all features. This bar tracks your progress. After 21 days, your analytics will freeze until you upgrade.',
  ),
  TourStep(
    title: 'Manage Your Wristbands',
    body:
        'Easily add new wristbands for your team members right here. You can assign them individually or in bulk.',
  ),
  TourStep(
    title: 'Google Business Profile Sync',
    body:
        'Track the status of your Google Business Profile sync and see key metrics derived from it. Upgrade to activate and unlock full insights!',
  ),
  TourStep(
    title: 'Weekly Progress + Baseline Block',
    body:
        'See the "before vs. after" impact of using Reviews Everywhere with key metrics like average rating, total reviews, and weekly growth after upgrading.',
  ),
  TourStep(
    title: 'Core Metrics at a Glance',
    body:
        'These cards show your most important metrics: total taps, active team members, and the number of unique customers you\'ve reached.',
  ),
  TourStep(
    title: 'Manage Remapping Credits',
    body:
        'Easily re-assign wristbands to different team members using remapping credits, essential for adapting to team changes.',
  ),
  TourStep(
    title: 'Track Team Activity',
    body:
        "This chart visualizes your team's daily tap activity, helping you spot trends and understand engagement over time.",
  ),
  TourStep(
    title: 'Boost Team Engagement',
    body:
        'Gamification features like the leaderboard and streak champions make performance fun and encourage friendly competition.',
  ),
  TourStep(
    title: 'Need Help? We\'re Here!',
    body:
        'Access support resources, FAQs, and contact our team anytime from the dashboard. We\'re always here to help you succeed.',
  ),
  TourStep(
    title: 'You\'re All Set!',
    body:
        'That\'s the end of the tour. Explore your dashboard, manage your wristbands, and start growing your reviews today!',
  ),
];
