import type { WorkItem } from "./types";

/**
 * NIARIM投稿元プロジェクトから作品へ引き継ぐ制作メタデータ。
 *
 * 既存のDynamoDB作品には属性が存在しないため、すべてoptionalにする。
 * YouTube由来の値ではなくNIARIM独自情報であり、縦画面モードと作品詳細の
 * 「どう作られた作品か」を示すためだけに利用する。
 */
export interface ProjectMetadataFields {
  projectFps?: number;
  projectFrameCount?: number;
  projectWorkSeconds?: number;
  projectCreatedAt?: string;
  projectCanvasWidth?: number;
  projectCanvasHeight?: number;
}

export type WorkWithProjectMetadata = WorkItem & ProjectMetadataFields;
