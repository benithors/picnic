import SwiftUI

struct EditorView: View {
    @ObservedObject var model: EditorViewModel
    let onSave: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    @State private var dragStart: CGPoint?
    @FocusState private var focusedTextID: UUID?
    @State private var toolbarFrame: CGRect = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.black

                Image(nsImage: model.image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                MouseTrackingView { point in
                    if !toolbarFrame.contains(point) {
                        model.updateCursorPoint(point)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(dragGesture)

                annotationLayer

                if let cropRect = model.cropRect {
                    cropOverlay(cropRect: cropRect, fullSize: proxy.size)
                        .allowsHitTesting(false)
                }

                editingOutline

                toolbar

                Button(action: onClose) {
                    EmptyView()
                }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .hidden()
            }
            .coordinateSpace(name: "editor")
            .ignoresSafeArea()
            .onPreferenceChange(ToolbarFrameKey.self) { newValue in
                toolbarFrame = newValue
            }
            .onAppear {
                model.updateViewSize(proxy.size)
            }
            .onChange(of: proxy.size) { newSize in
                model.updateViewSize(newSize)
            }
            .onChange(of: model.editingTextID) { newValue in
                if let newValue {
                    DispatchQueue.main.async {
                        focusedTextID = newValue
                    }
                } else {
                    focusedTextID = nil
                }
            }
            .onExitCommand {
                onClose()
            }
        }
    }

    private var editingOutline: some View {
        Rectangle()
            .stroke(Color(red: 0.15, green: 0.82, blue: 0.72).opacity(0.9), lineWidth: 4)
            .allowsHitTesting(false)
    }

    private var toolbar: some View {
        HStack {
            Spacer()
            toolbarContent
            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }

    private var toolbarContent: some View {
        HStack(spacing: 12) {
            toolButton(title: "Select", systemImage: "cursorarrow", tool: .select, shortcutKey: "1")
            toolButton(title: "Crop", systemImage: "crop", tool: .crop, shortcutKey: "2")
            toolButton(title: "Arrow", systemImage: "arrow.up.right", tool: .arrow, shortcutKey: "3")
            toolButton(title: "Text", systemImage: "textformat", tool: .text, shortcutKey: "4")

            Divider().frame(height: 20)

            Button(action: onSave) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)

            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ToolbarFrameKey.self, value: proxy.frame(in: .named("editor")))
            }
        )
    }

    private var annotationLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.arrows) { arrow in
                ArrowShape(start: arrow.start, end: arrow.end)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .allowsHitTesting(false)
            }
            if let currentArrow = model.currentArrow {
                ArrowShape(start: currentArrow.start, end: currentArrow.end)
                    .stroke(Color.red.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .allowsHitTesting(false)
            }
            ForEach(model.texts) { text in
                if model.editingTextID == text.id {
                    TextField("Text", text: Binding(
                        get: { text.text },
                        set: { model.updateText(id: text.id, text: $0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.black.opacity(0.4))
                    )
                    .offset(x: text.point.x, y: text.point.y)
                    .focused($focusedTextID, equals: text.id)
                    .onAppear {
                        DispatchQueue.main.async {
                            focusedTextID = text.id
                        }
                    }
                    .onSubmit { model.endTextEditing(switchToSelect: true) }
                } else {
                    Text(text.text)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.black.opacity(0.35))
                        )
                        .offset(x: text.point.x, y: text.point.y)
                        .allowsHitTesting(model.tool == .text)
                        .onTapGesture {
                            if model.tool == .text {
                                model.editingTextID = text.id
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func cropOverlay(cropRect: CGRect, fullSize: CGSize) -> some View {
        let fullRect = CGRect(origin: .zero, size: fullSize)
        return ZStack {
            Path { path in
                path.addRect(fullRect)
                path.addRect(cropRect)
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

            Rectangle()
                .path(in: cropRect)
                .stroke(Color.white, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func toolButton(title: String, systemImage: String, tool: EditorViewModel.Tool, shortcutKey: Character? = nil) -> some View {
        let button = Button(action: {
            model.selectTool(tool)
        }) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(model.tool == tool ? Color.white.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

        if let shortcutKey, model.editingTextID == nil {
            button.keyboardShortcut(KeyEquivalent(shortcutKey), modifiers: [])
        } else {
            button
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = value.startLocation
                    model.beginDrag(at: value.startLocation)
                }
                if let start = dragStart {
                    model.updateDrag(from: start, to: value.location)
                }
            }
            .onEnded { value in
                let start = dragStart ?? value.startLocation
                let distance = hypot(value.location.x - start.x, value.location.y - start.y)
                model.endDrag(from: start, to: value.location, isClick: distance < 3)
                dragStart = nil
            }
    }
}

struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 14
        let headAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let point2 = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        path.move(to: end)
        path.addLine(to: point1)
        path.move(to: end)
        path.addLine(to: point2)

        return path
    }
}

private struct ToolbarFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
