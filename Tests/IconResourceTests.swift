import AppKit

guard let image = NSImage(contentsOfFile: "assets/CodexPet.png") else {
    fatalError("Codex pet icon must load through AppKit")
}
guard image.size.width == 1024, image.size.height == 1024 else {
    fatalError("Codex pet icon must have a stable 1024x1024 source, got \(image.size)")
}
print("IconResourceTests: 1 passed")
