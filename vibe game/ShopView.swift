//
//  ShopView.swift
//  vibe game
//
//  ORBIT — the Star Shop. Spend banked stars on ship trails and planet themes.
//  All previews are drawn in code to match the in-game look.
//

import SwiftUI

struct ShopView: View {
    let model: GameModel
    @Binding var isPresented: Bool

    private let gold = Color(red: 1.0, green: 0.82, blue: 0.28)
    private let panel = Color(red: 0.06, green: 0.07, blue: 0.13)

    var body: some View {
        ZStack {
            // Dim backdrop that also swallows taps so the game doesn't start behind it.
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                header
                Divider().overlay(.white.opacity(0.1))
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section(title: "Trails") {
                            ForEach(GameModel.trails) { trail in
                                cosmeticCard(
                                    id: trail.id, name: trail.name, cost: trail.cost, kind: .trail,
                                    isSelected: model.selectedTrailID == trail.id
                                ) { trailPreview(trail) }
                            }
                        }
                        section(title: "Planet Themes") {
                            ForEach(GameModel.planets) { theme in
                                cosmeticCard(
                                    id: theme.id, name: theme.name, cost: theme.cost, kind: .planet,
                                    isSelected: model.selectedPlanetID == theme.id
                                ) { planetPreview(theme) }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: 460)
            .background(RoundedRectangle(cornerRadius: 28).fill(panel))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.08), lineWidth: 1))
            .padding(18)
            .shadow(color: .black.opacity(0.6), radius: 30)
        }
        .transition(.opacity)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("STAR SHOP")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                Text("\(model.starBalance)")
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(gold.opacity(0.15)))

            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(20)
    }

    // MARK: Section

    private func section<Content: View>(title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    content()
                }
            }
        }
    }

    // MARK: Card

    private func cosmeticCard<Preview: View>(
        id: String, name: String, cost: Int, kind: CosmeticKind,
        isSelected: Bool, @ViewBuilder preview: () -> Preview
    ) -> some View {
        let owned = model.isOwned(id)
        let affordable = model.starBalance >= cost

        return Button {
            model.selectOrBuy(id: id, cost: cost, kind: kind)
        } label: {
            VStack(spacing: 8) {
                preview()
                    .frame(width: 60, height: 60)

                Text(name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                statusLabel(owned: owned, isSelected: isSelected, cost: cost, affordable: affordable)
            }
            .frame(width: 104, height: 132)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(isSelected ? 0.10 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? gold : .white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1)
            )
            .opacity(owned || affordable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusLabel(owned: Bool, isSelected: Bool, cost: Int, affordable: Bool) -> some View {
        if isSelected {
            label("Equipped", color: gold, filled: true)
        } else if owned {
            label("Equip", color: .white.opacity(0.85), filled: false)
        } else {
            HStack(spacing: 3) {
                Image(systemName: "star.fill").font(.system(size: 10))
                Text("\(cost)").font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(affordable ? gold : .white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.06)))
        }
    }

    private func label(_ text: String, color: Color, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(filled ? .black : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(filled ? color : Color.white.opacity(0.08)))
    }

    // MARK: Previews (mini versions of the in-game art)

    private func trailPreview(_ trail: TrailStyle) -> some View {
        let color = model.shipColor
        return ZStack {
            Circle().fill(.white.opacity(0.03))
            switch trail.id {
            case "sparkle":
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(color.opacity(0.85 - Double(i) * 0.15))
                        .frame(width: 6 - CGFloat(i), height: 6 - CGFloat(i))
                        .offset(x: -8 - CGFloat(i) * 7, y: 0)
                }
                orbDot(color)
            case "ribbon":
                Capsule().fill(color.opacity(0.6)).frame(width: 40, height: 5).offset(y: -4)
                Capsule().fill(color.opacity(0.6)).frame(width: 40, height: 5).offset(y: 4)
                orbDot(color)
            case "pulse":
                Circle().stroke(color.opacity(0.5), lineWidth: 2).frame(width: 34, height: 34)
                Circle().stroke(color.opacity(0.3), lineWidth: 2).frame(width: 48, height: 48)
                orbDot(color)
            case "rainbow":
                Capsule()
                    .fill(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 42, height: 6)
                orbDot(color)
            default: // comet
                Capsule()
                    .fill(LinearGradient(colors: [.clear, color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 42, height: 6)
                orbDot(color)
            }
        }
    }

    private func orbDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .shadow(color: color.opacity(0.8), radius: 6)
            .offset(x: 16)
    }

    private func planetPreview(_ theme: PlanetTheme) -> some View {
        Circle()
            .fill(
                RadialGradient(colors: [theme.inner, theme.mid, theme.outer],
                               center: .init(x: 0.35, y: 0.35),
                               startRadius: 0, endRadius: 34)
            )
            .frame(width: 46, height: 46)
            .shadow(color: theme.glow.opacity(0.7), radius: 10)
    }
}
