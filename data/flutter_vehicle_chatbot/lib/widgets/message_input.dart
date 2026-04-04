import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback onAttachImage;
  final VoidCallback onStartVoiceInput;
  final VoidCallback onStopVoiceInput;
  final bool isEnabled;
  final bool isListening;
  final String recognizedText;

  const MessageInput({
    Key? key,
    required this.onSendMessage,
    required this.onAttachImage,
    required this.onStartVoiceInput,
    required this.onStopVoiceInput,
    this.isEnabled = true,
    this.isListening = false,
    this.recognizedText = '',
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void didUpdateWidget(MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update text field with recognized text
    if (widget.recognizedText.isNotEmpty && widget.recognizedText != oldWidget.recognizedText) {
      _controller.text = widget.recognizedText;
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            color: Colors.blue,
            onPressed: widget.isEnabled ? widget.onAttachImage : null,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.isEnabled && !widget.isListening,
              decoration: InputDecoration(
                hintText: widget.isListening ? 'Listening...' : 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: widget.isListening ? Colors.blue[50] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none),
            color: widget.isListening ? Colors.red : Colors.blue,
            onPressed: widget.isEnabled
                ? (widget.isListening ? widget.onStopVoiceInput : widget.onStartVoiceInput)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Colors.blue,
            onPressed: widget.isEnabled && !widget.isListening ? _handleSend : null,
          ),
        ],
      ),
    );
  }
}
