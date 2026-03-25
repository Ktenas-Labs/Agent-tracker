import 'package:flutter/material.dart';
import '../app/theme.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  static const _categories = [
    _ResourceCategory(
      title: 'Product Overview',
      icon: Icons.inventory_2_outlined,
      items: [
        _ResourceItem(
          title: 'SSLI Product Guide',
          description:
              'Comprehensive overview of Servicemembers\u2019 Group Life Insurance and supplemental products.',
          type: _ResourceType.document,
        ),
        _ResourceItem(
          title: 'Plan Comparison Sheet',
          description:
              'Side-by-side comparison of all available plan tiers, premiums, and benefits.',
          type: _ResourceType.document,
        ),
        _ResourceItem(
          title: 'Frequently Asked Questions',
          description:
              'Common questions from service members and recommended talking points.',
          type: _ResourceType.document,
        ),
      ],
    ),
    _ResourceCategory(
      title: 'Sales & Briefing Materials',
      icon: Icons.present_to_all_outlined,
      items: [
        _ResourceItem(
          title: 'Briefing Slide Deck',
          description:
              'Standard presentation slides for unit briefings with speaker notes.',
          type: _ResourceType.presentation,
        ),
        _ResourceItem(
          title: 'One-Pager Handout',
          description:
              'Printable single-page summary to distribute during briefings.',
          type: _ResourceType.document,
        ),
        _ResourceItem(
          title: 'Objection Handling Guide',
          description:
              'Responses to the most common objections and concerns raised during presentations.',
          type: _ResourceType.document,
        ),
      ],
    ),
    _ResourceCategory(
      title: 'Training & Onboarding',
      icon: Icons.school_outlined,
      items: [
        _ResourceItem(
          title: 'New Agent Onboarding Checklist',
          description:
              'Step-by-step checklist to get up and running in your first week.',
          type: _ResourceType.checklist,
        ),
        _ResourceItem(
          title: 'Product Training Video',
          description:
              'Recorded training session covering product details, pricing, and enrollment flow.',
          type: _ResourceType.video,
        ),
        _ResourceItem(
          title: 'Compliance & Regulations',
          description:
              'Key compliance requirements, do\u2019s and don\u2019ts for on-base briefings.',
          type: _ResourceType.document,
        ),
      ],
    ),
    _ResourceCategory(
      title: 'Tools & Templates',
      icon: Icons.build_outlined,
      items: [
        _ResourceItem(
          title: 'Follow-Up Email Templates',
          description:
              'Pre-written email templates for post-briefing follow-ups and scheduling.',
          type: _ResourceType.template,
        ),
        _ResourceItem(
          title: 'Enrollment Form (Fillable)',
          description:
              'Fillable PDF enrollment form for use during or after briefings.',
          type: _ResourceType.document,
        ),
        _ResourceItem(
          title: 'Weekly Call Script',
          description:
              'Recommended phone script for outreach calls to unit POCs.',
          type: _ResourceType.template,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = constraints.maxWidth >= 900
              ? 2
              : 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.menu_book_outlined,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agent Resource Center',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Documents, training materials, and tools to help you succeed.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFBFDBFE),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (crossCount == 1)
                  ...List.generate(_categories.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CategoryCard(category: _categories[i]),
                    );
                  })
                else
                  for (int i = 0; i < _categories.length; i += 2) ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: _CategoryCard(
                                  category: _categories[i])),
                          const SizedBox(width: 16),
                          Expanded(
                            child: i + 1 < _categories.length
                                ? _CategoryCard(
                                    category: _categories[i + 1])
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Data models ──────────────────────────────────────────────────────────────

enum _ResourceType { document, presentation, video, checklist, template }

extension _ResourceTypeExt on _ResourceType {
  IconData get icon => switch (this) {
        _ResourceType.document => Icons.description_outlined,
        _ResourceType.presentation => Icons.slideshow_outlined,
        _ResourceType.video => Icons.play_circle_outline,
        _ResourceType.checklist => Icons.checklist_outlined,
        _ResourceType.template => Icons.text_snippet_outlined,
      };

  String get label => switch (this) {
        _ResourceType.document => 'Document',
        _ResourceType.presentation => 'Presentation',
        _ResourceType.video => 'Video',
        _ResourceType.checklist => 'Checklist',
        _ResourceType.template => 'Template',
      };

  Color get color => switch (this) {
        _ResourceType.document => AppColors.primary,
        _ResourceType.presentation => const Color(0xFF8B5CF6),
        _ResourceType.video => const Color(0xFFEF4444),
        _ResourceType.checklist => AppColors.success,
        _ResourceType.template => AppColors.warning,
      };
}

class _ResourceItem {
  final String title;
  final String description;
  final _ResourceType type;

  const _ResourceItem({
    required this.title,
    required this.description,
    required this.type,
  });
}

class _ResourceCategory {
  final String title;
  final IconData icon;
  final List<_ResourceItem> items;

  const _ResourceCategory({
    required this.title,
    required this.icon,
    required this.items,
  });
}

// ── Category Card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});
  final _ResourceCategory category;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${category.items.length} items',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textDisabled),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(category.items.length, (i) {
            final item = category.items[i];
            return Column(
              children: [
                _ResourceTile(item: item),
                if (i < category.items.length - 1)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.border.withAlpha(60),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Resource Tile ────────────────────────────────────────────────────────────

class _ResourceTile extends StatefulWidget {
  const _ResourceTile({required this.item});
  final _ResourceItem item;

  @override
  State<_ResourceTile> createState() => _ResourceTileState();
}

class _ResourceTileState extends State<_ResourceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${widget.item.title} \u2014 coming soon'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered ? AppColors.surfaceHigh : Colors.transparent,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.item.type.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.item.type.icon,
                  size: 18,
                  color: widget.item.type.color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.item.type.color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: widget.item.type.color.withAlpha(60)),
                ),
                child: Text(
                  widget.item.type.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.item.type.color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: _hovered
                    ? AppColors.textSecondary
                    : AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
