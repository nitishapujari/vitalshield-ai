import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'presentation/providers/assistant_provider.dart';
import 'presentation/widgets/chat_bubble.dart';
import 'presentation/widgets/assistant_input.dart';
import 'presentation/widgets/typing_indicator.dart';
import 'presentation/widgets/conversation_header.dart';
import 'presentation/widgets/empty_conversation_state.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load persisted conversation on screen open
    Future.microtask(() {
      ref.read(assistantProvider.notifier).loadConversation();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _handleSend(String text) {
    ref.read(assistantProvider.notifier).sendMessage(text);
    _scrollToBottom();
    // Scroll again after response arrives
    Future.delayed(const Duration(milliseconds: 1200), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ──
          ConversationHeader(
            onClearConversation: state.messages.isNotEmpty
                ? () => ref.read(assistantProvider.notifier).clearConversation()
                : null,
          ),

          // ── Conversation Area ──
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : state.messages.isEmpty && !state.isTyping
                    ? EmptyConversationState(
                        onQuickPrompt: _handleSend,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                          vertical: AppSpacing.lg,
                        ),
                        itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.messages.length && state.isTyping) {
                            return const TypingIndicator();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ChatBubble(message: state.messages[index]),
                          );
                        },
                      ),
          ),

          // ── Input ──
          AssistantInput(onSend: _handleSend),
        ],
      ),
    );
  }
}
