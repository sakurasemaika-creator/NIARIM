import type { WorkItem } from "../../lib/types";

/**
 * 作品アイテムからクライアントへ公開してよいフィールドだけを抜き出す。
 * DynamoDBの内部キー（pk/sk/gsi*）・itemTypeはレスポンスに含めない。
 */
export function toPublicWork(item: WorkItem) {
  return {
    workId: item.workId,
    authorId: item.authorId,
    channelName: item.channelName,
    channelAvatarUrl: item.channelAvatarUrl,
    title: item.title,
    postedAt: item.postedAt,
    youtubeUrl: item.youtubeUrl,
    thumbnailUrl: item.thumbnailUrl,
    viewCount: item.viewCount,
    likeCount: item.likeCount,
    commentCount: item.commentCount,
    bookmarkCount: item.bookmarkCount,
    repostCount: item.repostCount,
    isShort: item.isShort,
    tags: item.tags,
    lockedTags: item.lockedTags,
    isNiarimPublished: item.isNiarimPublished,
  };
}
