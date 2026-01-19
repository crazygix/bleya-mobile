import '../../domain/repositories/message_repository.dart';

class GetThreadUseCase {
  final MessageRepository _messageRepository;

  GetThreadUseCase(this._messageRepository);

  Future<ThreadData> call(String messageId) async {
    return await _messageRepository.getThread(messageId);
  }
}
