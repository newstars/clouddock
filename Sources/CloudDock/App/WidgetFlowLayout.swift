import SwiftUI

struct WidgetFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let shouldWrap = currentX > 0 && currentX + spacing + size.width > maxWidth

            if shouldWrap {
                width = max(width, currentX)
                height += currentRowHeight + rowSpacing
                currentX = 0
                currentRowHeight = 0
            }

            if currentX > 0 {
                currentX += spacing
            }
            currentX += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }

        width = max(width, currentX)
        height += currentRowHeight

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let shouldWrap = currentX > bounds.minX && currentX + spacing + size.width > bounds.maxX

            if shouldWrap {
                currentX = bounds.minX
                currentY += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            if currentX > bounds.minX {
                currentX += spacing
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
