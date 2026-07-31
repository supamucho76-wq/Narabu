import SwiftUI

/// 行列の先にあった場所を、クリア画面で大きく見せる。
struct LandmarkView: View {
    let stage: Stage
    /// 影だけ見せる。次のステージの予告に使う。
    var isSilhouette = false

    var body: some View {
        Canvas { context, size in
            LandmarkRenderer.draw(
                stage: stage,
                in: context,
                rect: CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.94),
                silhouette: isSilhouette
            )
        }
        .frame(height: 132)
    }
}
