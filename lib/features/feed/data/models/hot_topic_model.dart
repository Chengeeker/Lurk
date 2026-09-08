class TiebaHotTopicModel {
  final String topicId;
  final String topicName;
  final String topicDesc;
  final String topicPic;
  final String topicAvatar;
  final String topicUrl;
  final int discussNum;
  final int idxNum;
  final int createTime;

  const TiebaHotTopicModel({
    required this.topicId,
    required this.topicName,
    this.topicDesc = "",
    this.topicPic = "",
    this.topicAvatar = "",
    this.topicUrl = "",
    this.discussNum = 0,
    this.idxNum = 0,
    this.createTime = 0,
  });

  factory TiebaHotTopicModel.fromJson(Map<String, dynamic> json) {
    return TiebaHotTopicModel(
      topicId: json["topic_id"]?.toString() ?? "",
      topicName: json["topic_name"]?.toString() ?? "",
      topicDesc: json["topic_desc"]?.toString() ?? json["abstract"]?.toString() ?? "",
      topicPic: json["topic_pic"]?.toString() ?? "",
      topicAvatar: json["topic_avatar"]?.toString() ?? json["topic_default_avatar"]?.toString() ?? "",
      topicUrl: json["topic_url"]?.toString() ?? "",
      discussNum: int.tryParse(json["discuss_num"]?.toString() ?? "0") ?? 0,
      idxNum: int.tryParse(json["idx_num"]?.toString() ?? "0") ?? 0,
      createTime: int.tryParse(json["create_time"]?.toString() ?? "0") ?? 0,
    );
  }

  String get formattedDiscussNum {
    if (discussNum >= 10000) {
      return "${(discussNum / 10000).toStringAsFixed(1)}万讨论";
    }
    return "$discussNum讨论";
  }
}
