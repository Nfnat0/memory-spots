import Foundation
import SwiftData

enum SeedDataService {
    private static let awsSetName = "AWS資格 五反田ルート"

    @MainActor
    static func seedAWSExamSetIfNeeded(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<MemorySet>(
            predicate: #Predicate { $0.name == awsSetName }
        )
        descriptor.fetchLimit = 1

        guard (try? modelContext.fetch(descriptor))?.isEmpty != false else {
            return
        }

        do {
            try seedAWSExamSet(modelContext: modelContext)
        } catch {
            assertionFailure("Failed to seed AWS exam set: \(error)")
        }
    }

    @MainActor
    private static func seedAWSExamSet(modelContext: ModelContext) throws {
        let memorySet = MemorySet(
            name: awsSetName,
            detail: "指定された五反田周辺の写真を使ったAWS資格試験用の記憶セット。"
        )
        let theme = MemoryTheme(setId: memorySet.id, name: "AWS資格", colorName: "yellow")

        modelContext.insert(memorySet)
        modelContext.insert(theme)

        for (photoIndex, photoSeed) in photoSeeds.enumerated() {
            let imagePath = try ImageStore.saveBundledImage(
                named: photoSeed.resourceName,
                extension: "jpeg"
            )
            let photo = MemoryPhoto(
                setId: memorySet.id,
                title: photoSeed.title,
                imagePath: imagePath,
                orderIndex: photoIndex
            )
            modelContext.insert(photo)

            for (itemIndex, itemSeed) in photoSeed.items.enumerated() {
                modelContext.insert(
                    MemoryItem(
                        photoId: photo.id,
                        themeId: theme.id,
                        frontText: itemSeed.front,
                        backText: itemSeed.back,
                        x: itemSeed.x,
                        y: itemSeed.y,
                        orderIndex: itemIndex
                    )
                )
            }
        }

        try modelContext.save()
    }
}

private struct SeedPhoto {
    let title: String
    let resourceName: String
    let items: [SeedItem]
}

private struct SeedItem {
    let front: String
    let back: String
    let x: Double
    let y: Double
}

private let photoSeeds: [SeedPhoto] = [
    SeedPhoto(
        title: "五反田の歩道",
        resourceName: "gotanda_sidewalk",
        items: [
            SeedItem(
                front: "AWS Well-Architected",
                back: "6本柱: 運用上の優秀性、セキュリティ、信頼性、パフォーマンス効率、コスト最適化、持続可能性。",
                x: 0.24,
                y: 0.74
            ),
            SeedItem(
                front: "責任共有モデル",
                back: "AWSはクラウドのセキュリティ、利用者はクラウド内のセキュリティ。OS、データ、IAM、ネットワーク設定は主に利用者側。",
                x: 0.52,
                y: 0.46
            ),
            SeedItem(
                front: "IAM最小権限",
                back: "必要な操作だけを許可する。ユーザーへ直接権限を盛りすぎず、グループ/ロール/ポリシーで管理する。",
                x: 0.69,
                y: 0.24
            )
        ]
    ),
    SeedPhoto(
        title: "道路沿いの柵",
        resourceName: "gotanda_road",
        items: [
            SeedItem(
                front: "VPCの基本",
                back: "VPCは論理的に分離されたネットワーク。サブネット、ルートテーブル、Internet Gateway、NAT Gatewayで通信経路を設計する。",
                x: 0.28,
                y: 0.62
            ),
            SeedItem(
                front: "Security Group",
                back: "インスタンス単位のステートフルな仮想ファイアウォール。許可ルールだけを書く。戻り通信は自動的に許可される。",
                x: 0.51,
                y: 0.38
            ),
            SeedItem(
                front: "ALB / Auto Scaling",
                back: "ALBでHTTP/HTTPSを分散し、Auto Scalingで需要に応じて台数を調整する。可用性と弾力性の定番構成。",
                x: 0.72,
                y: 0.24
            ),
            SeedItem(
                front: "Route 53",
                back: "DNSサービス。加重、レイテンシー、フェイルオーバーなどのルーティングポリシーを選べる。",
                x: 0.79,
                y: 0.68
            )
        ]
    ),
    SeedPhoto(
        title: "五反田駅入口",
        resourceName: "gotanda_station",
        items: [
            SeedItem(
                front: "S3ストレージクラス",
                back: "頻繁アクセスはStandard、低頻度はStandard-IA/One Zone-IA、アーカイブはGlacier系。ライフサイクルで移行できる。",
                x: 0.26,
                y: 0.82
            ),
            SeedItem(
                front: "RDS Multi-AZ",
                back: "高可用性のため別AZにスタンバイを置く。読み取り性能向上はRead Replica、障害対策はMulti-AZ。",
                x: 0.48,
                y: 0.52
            ),
            SeedItem(
                front: "DynamoDB",
                back: "フルマネージドNoSQL。キー設計が重要。DAXは読み取りキャッシュ、Global Tablesはマルチリージョン複製。",
                x: 0.63,
                y: 0.42
            ),
            SeedItem(
                front: "CloudWatch",
                back: "メトリクス、ログ、アラームを扱う監視サービス。しきい値超過でSNS通知やAuto Scaling連携ができる。",
                x: 0.74,
                y: 0.18
            ),
            SeedItem(
                front: "CloudTrail",
                back: "AWS API操作履歴を記録する。誰が、いつ、何をしたかの監査に使う。セキュリティ問題の調査でも重要。",
                x: 0.82,
                y: 0.75
            )
        ]
    )
]
