import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _page = 0;
  bool _isFinishing = false;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      keyName: 'welcome',
      icon: Icons.album_rounded,
      eyebrow: 'WELCOME TO GROOVEFOLIO',
      title: 'Your record shelf, remembered',
      body:
          'Build your collection, remember every spin, and rediscover records worth playing again.',
      bullets: [
        'Local-first: your collection stays on your device',
        'No Groovefolio account required',
      ],
    ),
    _OnboardingPageData(
      keyName: 'add-records',
      icon: Icons.library_add_rounded,
      eyebrow: 'BUILD YOUR SHELF',
      title: 'Add records your way',
      body:
          'Enter a record manually, search Discogs for metadata, scan a barcode, or optionally import a Discogs collection.',
      bullets: [
        'Artwork, genres, release details, and tracklists',
        'Discogs connection is optional',
      ],
    ),
    _OnboardingPageData(
      keyName: 'collection',
      icon: Icons.grid_view_rounded,
      eyebrow: 'EXPLORE YOUR COLLECTION',
      title: 'Find the right record fast',
      body:
          'Search your shelf, sort by recent or most played, filter by genre, and open a record for its complete details.',
      bullets: [
        'Search, sort, and genre filters',
        'Album details, tracklists, and play history',
      ],
    ),
    _OnboardingPageData(
      keyName: 'log-plays',
      icon: Icons.play_circle_outline_rounded,
      eyebrow: 'REMEMBER EVERY SPIN',
      title: 'Log a play in seconds',
      body:
          'Choose a record, select the full album or a side, adjust the date if needed, and save the play.',
      bullets: [
        'Log from Collection or Album Details',
        'Backdate plays you forgot to record',
      ],
    ),
    _OnboardingPageData(
      keyName: 'swipe-actions',
      icon: Icons.swipe_left_rounded,
      eyebrow: 'QUICK ACTIONS',
      title: 'Swipe left to manage a record',
      body:
          'On your Collection screen, swipe a record to the left to reveal Edit and Delete.',
      bullets: [
        'Tap normally to open Album Details',
        'Deletion always asks for confirmation',
      ],
    ),
    _OnboardingPageData(
      keyName: 'insights',
      icon: Icons.insights_rounded,
      eyebrow: 'MAKE YOUR SHELF PERSONAL',
      title: 'Stats and picks improve as you listen',
      body:
          'Stats turn your play history into trends. Discover uses your own shelf and listening habits for explainable recommendations.',
      bullets: [
        'See plays, genres, eras, and favorites',
        'Understand why each record is recommended',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isLastPage = _page == _pages.length - 1;

    return PopScope(
      canPop: widget.replay,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.replay,
          title: const Text('Getting started'),
          actions: [
            if (!isLastPage)
              TextButton(
                key: const Key('onboarding-skip'),
                onPressed: _isFinishing ? null : _finish,
                child: const Text('Skip'),
              ),
            SizedBox(width: tokens.space8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  key: const Key('onboarding-pages'),
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) => _OnboardingPage(
                    key: Key('onboarding-page-${_pages[index].keyName}'),
                    data: _pages[index],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space16,
                  tokens.space8,
                  tokens.space16,
                  tokens.space16,
                ),
                child: Column(
                  children: [
                    Semantics(
                      label: 'Page ${_page + 1} of ${_pages.length}',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var index = 0; index < _pages.length; index++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: index == _page ? 24 : 8,
                              height: 8,
                              margin: EdgeInsets.symmetric(
                                horizontal: tokens.space4,
                              ),
                              decoration: BoxDecoration(
                                color: index == _page
                                    ? AppThemeTokens.accent
                                    : tokens.textMuted.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.space16),
                    Row(
                      children: [
                        if (_page > 0) ...[
                          OutlinedButton(
                            key: const Key('onboarding-back'),
                            onPressed: _isFinishing ? null : _previous,
                            child: const Text('Back'),
                          ),
                          SizedBox(width: tokens.space12),
                        ],
                        Expanded(
                          child: FilledButton(
                            key: Key(
                              isLastPage
                                  ? 'onboarding-get-started'
                                  : 'onboarding-next',
                            ),
                            onPressed: _isFinishing
                                ? null
                                : isLastPage
                                ? _finish
                                : _next,
                            child: _isFinishing && isLastPage
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(isLastPage ? 'Get started' : 'Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _isFinishing = true);
    try {
      await ref.read(onboardingServiceProvider).completeOnboarding();
      ref.invalidate(onboardingRequiredProvider);
      if (!mounted) return;
      if (widget.replay && context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.collection);
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({super.key, required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        tokens.space24,
        tokens.space24,
        tokens.space24,
        tokens.space16,
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: AppThemeTokens.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: AppThemeTokens.accent),
          ),
          SizedBox(height: tokens.space32),
          Text(
            data.eyebrow,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.labelLarge?.copyWith(
              color: AppThemeTokens.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: tokens.space8),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: tokens.space16),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyLarge?.copyWith(
              color: tokens.textMuted,
              height: 1.45,
            ),
          ),
          SizedBox(height: tokens.space24),
          Card(
            child: Padding(
              padding: EdgeInsets.all(tokens.space16),
              child: Column(
                children: [
                  for (var index = 0; index < data.bullets.length; index++) ...[
                    _OnboardingBullet(text: data.bullets[index]),
                    if (index != data.bullets.length - 1)
                      SizedBox(height: tokens.space12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBullet extends StatelessWidget {
  const _OnboardingBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppThemeTokens.accent,
          size: 20,
        ),
        SizedBox(width: context.tokens.space12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.keyName,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.bullets,
  });

  final String keyName;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> bullets;
}
