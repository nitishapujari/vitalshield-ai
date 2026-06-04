import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/conversation_model.dart';
import '../providers/assistant_provider.dart';

/// A single chat bubble widget.
/// User messages align right with primary color.
/// Assistant messages align left with surface color.
class ChatBubble extends ConsumerWidget {
  final ConversationMessage message;

  const ChatBubble({super.key, required this.message});

  bool get _isUser => message.sender == MessageSender.user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: _isUser ? 48 : 0,
          right: _isUser ? 0 : 48,
          bottom: AppSpacing.sm,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _isUser ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusLg),
            topRight: const Radius.circular(AppSpacing.radiusLg),
            bottomLeft: Radius.circular(_isUser ? AppSpacing.radiusLg : AppSpacing.xs),
            bottomRight: Radius.circular(_isUser ? AppSpacing.xs : AppSpacing.radiusLg),
          ),
          border: Border.all(
            color: _isUser ? AppColors.primary.withValues(alpha: 0.2) : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _isUser ? AppColors.textPrimary : AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            if (message.contextTag == 'error') ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(assistantProvider.notifier).retryLastMessage();
                    },
                    icon: const Icon(LucideIcons.refresh_cw, size: 12, color: AppColors.primaryLight),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
