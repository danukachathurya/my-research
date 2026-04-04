class ConversationResponse {
  final String response;
  final String sessionId;
  final bool isComplete;
  final String? nextQuestion;
  final List<String>? suggestions;

  ConversationResponse({
    required this.response,
    required this.sessionId,
    this.isComplete = false,
    this.nextQuestion,
    this.suggestions,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) {
    // Debug: Print what we receive
    print('ConversationResponse.fromJson: $json');

    // Try multiple possible field names for the message
    String message = '';
    String? nextQuestion;

    if (json.containsKey('message') && json['message'] != null) {
      message = json['message'].toString();
    } else if (json.containsKey('response') && json['response'] != null) {
      message = json['response'].toString();
    } else if (json.containsKey('error') && json['error'] != null) {
      message = 'Error: ${json['error']}';
    }

    // Handle 'question' field - it can be a string or an object
    if (json.containsKey('question') && json['question'] != null) {
      if (json['question'] is Map) {
        // Question is an object with question_text
        final questionObj = json['question'] as Map<String, dynamic>;
        final questionText = questionObj['question_text']?.toString() ?? '';

        // If message is empty, use the question text as the message
        if (message.isEmpty) {
          message = questionText;
        } else {
          // Otherwise, append the question
          message = '$message\n\n$questionText';
        }

        nextQuestion = questionText;

        // Handle options if present
        if (questionObj.containsKey('options') && questionObj['options'] is List) {
          final options = List<String>.from(questionObj['options']);
          message = '$message\n\nOptions:\n${options.map((o) => '• $o').join('\n')}';
        }
      } else {
        // Question is a simple string
        nextQuestion = json['question'].toString();
        if (message.isEmpty) {
          message = nextQuestion!;
        }
      }
    }

    // Try multiple possible field names for session_id
    String sessionId = '';
    if (json.containsKey('session_id') && json['session_id'] != null) {
      sessionId = json['session_id'].toString();
    }

    return ConversationResponse(
      response: message,
      sessionId: sessionId,
      isComplete: json['is_complete'] == true || json['status'] == 'complete',
      nextQuestion: nextQuestion,
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'response': response,
      'session_id': sessionId,
      'is_complete': isComplete,
      'next_question': nextQuestion,
      'suggestions': suggestions,
    };
  }
}
