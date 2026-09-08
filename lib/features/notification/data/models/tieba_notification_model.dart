class TiebaNotificationModel {
  final String title;
  final String content;
  final String fname;
  final String threadId;
  final String postId;
  final String quoteContent;
  final String authorName;
  final String authorPortrait;
  final String authorId;
  final int time;

  const TiebaNotificationModel({
    required this.title,
    required this.content,
    this.fname = "",
    this.threadId = "",
    this.postId = "",
    this.quoteContent = "",
    this.authorName = "",
    this.authorPortrait = "",
    this.authorId = "",
    this.time = 0,
  });

  factory TiebaNotificationModel.fromJson(Map<String, dynamic> json) {
    final replyer = json["replyer"] as Map<String, dynamic>?;
    final String authorName = replyer?["name_show"]?.toString() ??
        replyer?["name"]?.toString() ??
        json["author"]?.toString() ??
        "贴吧吧友";
    final String authorPortrait = replyer?["portrait"]?.toString() ?? "";
    final String authorId = replyer?["id"]?.toString() ?? json["author_id"]?.toString() ?? "";

    return TiebaNotificationModel(
      title: json["title"]?.toString() ?? json["fname"]?.toString() ?? "",
      content: json["content"]?.toString() ?? "",
      fname: json["fname"]?.toString() ?? "",
      threadId: json["thread_id"]?.toString() ?? json["tid"]?.toString() ?? json["kz"]?.toString() ?? "",
      postId: json["post_id"]?.toString() ?? json["pid"]?.toString() ?? "",
      quoteContent: json["quote_content"]?.toString() ?? "",
      authorName: authorName,
      authorPortrait: authorPortrait,
      authorId: authorId,
      time: int.tryParse(json["time"]?.toString() ?? "0") ?? 0,
    );
  }
}
