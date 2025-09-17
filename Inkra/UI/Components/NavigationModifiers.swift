import SwiftUI

struct NavigationDestinationModifier<Destination: View>: ViewModifier {
    @Binding var isPresented: Bool
    let destination: () -> Destination
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .navigationDestination(isPresented: $isPresented, destination: destination)
        } else {
            content
                .background(
                    NavigationLink(
                        destination: destination(),
                        isActive: $isPresented,
                        label: { EmptyView() }
                    ).hidden()
                )
        }
    }
}

struct NavigationDestinationProjectModifier<Destination: View>: ViewModifier {
    @Binding var item: Project?
    let destination: (Project) -> Destination
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .navigationDestination(item: $item, destination: destination)
        } else {
            content
                .background(
                    NavigationLink(
                        destination: item.map { AnyView(destination($0)) } ?? AnyView(EmptyView()),
                        isActive: Binding(
                            get: { item != nil },
                            set: { isActive in
                                if !isActive {
                                    item = nil
                                }
                            }
                        ),
                        label: { EmptyView() }
                    ).hidden()
                )
        }
    }
}