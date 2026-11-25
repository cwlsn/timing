import Foundation

/// The picture that labels a timer.
public enum TimerIcon {
    public static let fallback = "⏲️"

    /// First match wins, so the more particular words come first.
    private static let words: [(icon: String, words: [String])] = [
        ("🥞", ["pancake", "crepe", "waffle"]), ("🍳", ["fried egg", "omelette", "omelet", "fry", "pan"]),
        ("🥚", ["egg"]), ("🍚", ["rice", "risotto"]), ("🍝", ["pasta", "spaghetti", "penne", "linguine", "lasagna"]),
        ("🍜", ["noodle", "ramen", "pho"]), ("🍕", ["pizza"]), ("🍔", ["burger"]), ("🥩", ["steak", "beef", "roast"]),
        ("🍗", ["chicken", "turkey", "wing"]), ("🥓", ["bacon"]), ("🐟", ["fish", "salmon", "cod", "tuna"]),
        ("🍤", ["shrimp", "prawn"]), ("🍟", ["fries", "chips"]), ("🥔", ["potato"]), ("🥦", ["broccoli", "vegetable", "veg"]),
        ("🥕", ["carrot"]), ("🌽", ["corn"]), ("🫘", ["bean", "lentil"]), ("🍲", ["soup", "stew", "stock", "curry", "chili"]),
        ("🍪", ["cookie", "biscuit"]), ("🧁", ["muffin", "cupcake"]), ("🎂", ["cake"]), ("🥧", ["pie"]),
        ("🍞", ["bread", "sourdough", "dough", "loaf", "toast", "proof"]), ("🍵", ["tea", "matcha"]), ("☕️", ["coffee", "espresso"]),
        ("🧺", ["laundry", "washing", "dryer"]), ("💤", ["nap", "rest"]), ("🔥", ["grill", "bbq", "oven", "preheat"]),
    ]

    public static let choices = words.map(\.icon) + [fallback]

    public static func suggestion(for label: String) -> String? {
        let text = label.lowercased()
        let tokens = text.split { !$0.isLetter }.map(String.init)
        return words.first { entry in
            entry.words.contains { word in
                word.contains(" ") ? text.contains(word) : tokens.contains { $0 == word || $0 == word + "s" || $0 == word + "es" }
            }
        }?.icon
    }
}
