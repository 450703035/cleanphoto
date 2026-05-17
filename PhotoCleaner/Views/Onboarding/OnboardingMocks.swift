import SwiftUI

// MARK: - Cell state
enum PhotoCellState {
    case normal   // full-colour photo
    case dim      // grayscale + low opacity (will-be-deleted candidate)
    case gone     // dashed empty slot (already cleared)
}

// MARK: - PhotoGridMock
/// 3×3 thumbnail grid with state-based cell rendering and a top-right pill
/// badge. The grid demonstrates "before / after" clean-up: some cells normal,
/// some dimmed, some empty.
struct PhotoGridMock: View {
    let imageNames: [String]      // exactly 9 names; `gone` cells ignore name
    let states: [PhotoCellState]  // exactly 9 states
    let badgeText: String

    private let cellSize: CGFloat = 48
    private let cellSpacing: CGFloat = 3

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: cellSpacing) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<3, id: \.self) { col in
                            let idx = row * 3 + col
                            cell(state: states[idx], imageName: imageNames[idx])
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }

            Text(badgeText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(AppColors.purple))
                .shadow(color: AppColors.purple.opacity(0.5), radius: 14, y: 4)
                .offset(x: 14, y: -10)
        }
    }

    @ViewBuilder
    private func cell(state: PhotoCellState, imageName: String) -> some View {
        switch state {
        case .normal:
            Image(imageName)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .dim:
            Image(imageName)
                .resizable()
                .scaledToFill()
                .grayscale(1)
                .opacity(0.22)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .gone:
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppColors.subtleBorder, style: StrokeStyle(lineWidth: 1, dash: [3]))
        }
    }
}

// MARK: - PhotoStackMock
/// Three photos in a "fan" stack. Front photo carries a score pill (bottom-
/// right) and a category tag (top-left). Used as page 2's hero.
struct PhotoStackMock: View {
    let backImageName: String
    let midImageName: String
    let frontImageName: String
    let scoreText: String
    let categoryTag: String

    private let cardSize = CGSize(width: 130, height: 160)

    var body: some View {
        ZStack {
            Image(backImageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(0.6)
                .rotationEffect(.degrees(-8))
                .offset(x: -14, y: 8)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Image(midImageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(0.85)
                .rotationEffect(.degrees(5))
                .offset(x: 10, y: -4)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Image(frontImageName)
                .resizable()
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .overlay(alignment: .topLeading) {
                    Text(categoryTag)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.purple.opacity(0.9)))
                        .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(scoreText)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule().stroke(AppColors.green.opacity(0.5), lineWidth: 0.5)
                                )
                        )
                        .padding(8)
                }
        }
        .frame(width: cardSize.width + 30, height: cardSize.height + 20)
    }
}
