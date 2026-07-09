import SwiftUI

struct TestNav: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Content").padding(.top, 100)
            }
            .navigationTitle("Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {}
                }
            }
        }
    }
}
