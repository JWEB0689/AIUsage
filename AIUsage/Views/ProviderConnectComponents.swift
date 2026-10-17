import SwiftUI

// MARK: - Connect Sheet Building Blocks
// 连接弹窗共用的展示块。Claude 订阅与其他服务商走同一套「检测 → 确认 → 连接 → 显示额度」流程，
// 视觉也保持一致：账号卡片（首字母头像 + 套餐徽标）、说明卡片、进度行与额度条。

struct ConnectAccountCard<Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var plan: String?
    let caption: String
    let tint: Color
    var checked = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.14))
                Text(String(title.prefix(1)).uppercased())
                    .font(.headline).foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.headline).lineLimit(1).truncationMode(.middle)
                    if let plan { GatewayQuietBadge(text: plan, tint: tint) }
                }
                Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            trailing()
            if checked {
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppSurface.card(colorScheme)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppStroke.card(colorScheme), lineWidth: 1))
    }
}

extension ConnectAccountCard where Trailing == EmptyView {
    init(title: String, plan: String?, caption: String, tint: Color, checked: Bool = false) {
        self.init(title: title, plan: plan, caption: caption, tint: tint, checked: checked) { EmptyView() }
    }
}

struct ConnectMessageCard: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if !detail.isEmpty {
                    Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct ConnectProgressRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
    }
}

struct ConnectWaitingRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProgressView().controlSize(.small).padding(.top, 1)
            Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ConnectQuotaRow: View {
    let label: String
    /// 剩余百分比（0–100）。
    let remaining: Double
    var labelWidth: CGFloat = 64

    var body: some View {
        let clamped = max(0, min(100, remaining))
        let tint: Color = clamped <= 12 ? .red : clamped <= 30 ? .orange : .green
        HStack(spacing: 10) {
            Text(label).font(.callout).lineLimit(1).truncationMode(.tail).frame(width: labelWidth, alignment: .leading)
            ProgressView(value: clamped, total: 100).tint(tint)
            Text(L("\(Int(clamped.rounded()))% left", "剩余 \(Int(clamped.rounded()))%"))
                .font(.callout.monospacedDigit()).frame(width: 78, alignment: .trailing)
        }
    }
}
