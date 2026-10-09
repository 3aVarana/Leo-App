import Foundation

/// A suggested topic for an age group.
nonisolated struct DefaultTopic: Identifiable, Sendable {
    /// Stable key, persisted when the reader turns the topic off. Never change it.
    let id: String
    /// Shown in the topic list, in the reader's language.
    let name: LocalizedStringResource
    /// The English phrase used in prompts.
    let prompt: String
}

nonisolated extension DefaultTopic {
    /// Topics whose prompt asks for a story or fiction, such as "a short story about friendship"
    /// or "a survival story", are stories; the rest, "music history" included, are informative.
    var kind: TopicKind {
        let words = prompt.split(separator: " ")
        return words.contains { ["story", "fiction", "fictional"].contains($0) } ? .story : .informative
    }

    var roundTopic: RoundTopic {
        RoundTopic(prompt: prompt, name: String(localized: name), kind: kind)
    }
}

/// A topic the reader added, after the model reviewed it.
nonisolated struct CustomTopic: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// The model's cleaned-up phrase, in the language the reader typed it in. Used for display and prompts.
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

nonisolated extension CustomTopic {
    /// The reader's phrase is both what the model writes about and what the reader sees.
    /// Informative for now, whatever the reader typed.
    var roundTopic: RoundTopic {
        RoundTopic(prompt: name, name: name)
    }
}

/// Suggested topics per age group. One is picked per exercise so a round stays varied.
nonisolated enum DefaultTopics {
    static func topics(for group: AgeGroup) -> [DefaultTopic] {
        switch group {
        case .six: sixToEight
        case .nine: nineToEleven
        case .twelve: twelveToFourteen
        case .fifteen: fifteenToSeventeen
        case .adult: adult
        }
    }

    private static let sixToEight = [
        DefaultTopic(id: "pets-farm-animals", name: "Pets and farm animals", prompt: "pets and farm animals"),
        DefaultTopic(id: "dinosaurs", name: "Dinosaurs", prompt: "dinosaurs"),
        DefaultTopic(id: "seasons", name: "The seasons", prompt: "the seasons of the year"),
        DefaultTopic(id: "day-at-school", name: "A day at school", prompt: "a day at school"),
        DefaultTopic(
            id: "dragons-fairies",
            name: "Friendly dragons and fairies",
            prompt: "friendly dragons and fairies",
        ),
        DefaultTopic(id: "beach", name: "The beach", prompt: "a day at the beach"),
        DefaultTopic(id: "insects-bugs", name: "Insects and bugs", prompt: "insects and bugs"),
        DefaultTopic(id: "helping-at-home", name: "Helping at home", prompt: "helping at home"),
        DefaultTopic(id: "birthday-parties", name: "Birthday parties", prompt: "birthday parties"),
        DefaultTopic(
            id: "lost-toy",
            name: "A lost toy finds its way home",
            prompt: "a story about a lost toy that finds its way home",
        ),
        DefaultTopic(id: "trains-trucks", name: "Trains and trucks", prompt: "trains and trucks"),
        DefaultTopic(id: "moon-stars", name: "The moon and stars", prompt: "the moon and stars"),
        DefaultTopic(id: "baking-cookies", name: "Baking cookies", prompt: "baking cookies"),
        DefaultTopic(id: "playground-games", name: "Playground games", prompt: "playground games"),
        DefaultTopic(id: "kind-robot", name: "A kind robot", prompt: "a story about a kind robot"),
    ]

    private static let nineToEleven = [
        DefaultTopic(id: "wild-animals", name: "Wild animals", prompt: "wild animals"),
        DefaultTopic(id: "volcanoes", name: "Volcanoes", prompt: "volcanoes"),
        DefaultTopic(id: "solar-system", name: "The solar system", prompt: "the solar system"),
        DefaultTopic(id: "pirates-treasure", name: "Pirates and treasure", prompt: "pirates and treasure"),
        DefaultTopic(id: "inventors", name: "Inventors", prompt: "famous inventors"),
        DefaultTopic(id: "rainforests", name: "Rainforests", prompt: "rainforests"),
        DefaultTopic(id: "dinosaurs-fossils", name: "Dinosaurs and fossils", prompt: "dinosaurs and fossils"),
        DefaultTopic(id: "sports-heroes", name: "Sports heroes", prompt: "sports heroes"),
        DefaultTopic(
            id: "school-mystery",
            name: "A mystery at school",
            prompt: "a short story about a mystery at school",
        ),
        DefaultTopic(id: "ocean-floor", name: "The ocean floor", prompt: "the ocean floor"),
        DefaultTopic(id: "ancient-egypt", name: "Ancient Egypt", prompt: "ancient Egypt"),
        DefaultTopic(id: "how-machines-work", name: "How machines work", prompt: "how machines work"),
        DefaultTopic(id: "video-games", name: "Video games", prompt: "video games"),
        DefaultTopic(id: "recycling", name: "Recycling", prompt: "recycling"),
        DefaultTopic(
            id: "magical-adventure",
            name: "A magical adventure",
            prompt: "a short story about a magical adventure",
        ),
    ]

    private static let twelveToFourteen = [
        DefaultTopic(id: "space-exploration", name: "Space exploration", prompt: "space exploration"),
        DefaultTopic(id: "climate-weather", name: "Climate and weather", prompt: "climate and weather"),
        DefaultTopic(id: "ancient-civilizations", name: "Ancient civilizations", prompt: "ancient civilizations"),
        DefaultTopic(id: "human-body", name: "The human body", prompt: "the human body"),
        DefaultTopic(id: "famous-explorers", name: "Famous explorers", prompt: "famous explorers"),
        DefaultTopic(id: "inventions", name: "Inventions", prompt: "inventions"),
        DefaultTopic(id: "animal-behavior", name: "Animal behavior", prompt: "animal behavior"),
        DefaultTopic(id: "mythology", name: "Mythology", prompt: "mythology"),
        DefaultTopic(
            id: "friendship-story",
            name: "A story about friendship",
            prompt: "a short story about friendship",
        ),
        DefaultTopic(id: "coding-robots", name: "Coding and robots", prompt: "coding and robots"),
        DefaultTopic(id: "music-history", name: "Music history", prompt: "music history"),
        DefaultTopic(id: "survival-stories", name: "Survival stories", prompt: "a survival story"),
        DefaultTopic(id: "natural-disasters", name: "Natural disasters", prompt: "natural disasters"),
        DefaultTopic(id: "world-cultures", name: "World cultures", prompt: "world cultures"),
        DefaultTopic(id: "history-mysteries", name: "Mysteries of history", prompt: "mysteries of history"),
    ]

    private static let fifteenToSeventeen = [
        DefaultTopic(id: "space-exploration", name: "Space exploration", prompt: "space exploration"),
        DefaultTopic(id: "ocean-life", name: "Ocean life", prompt: "ocean life"),
        DefaultTopic(id: "climate-weather", name: "Climate and weather", prompt: "climate and weather"),
        DefaultTopic(id: "ancient-civilizations", name: "Ancient civilizations", prompt: "ancient civilizations"),
        DefaultTopic(
            id: "world-changing-inventions",
            name: "Inventions that changed the world",
            prompt: "inventions that changed the world",
        ),
        DefaultTopic(id: "music-history", name: "Music and its history", prompt: "music and its history"),
        DefaultTopic(id: "sports-science", name: "Sports science", prompt: "sports science"),
        DefaultTopic(
            id: "social-media-friendship",
            name: "Social media and friendship",
            prompt: "social media and friendship",
        ),
        DefaultTopic(id: "animal-behavior", name: "Animal behavior", prompt: "animal behavior"),
        DefaultTopic(
            id: "volcanoes-earthquakes",
            name: "Volcanoes and earthquakes",
            prompt: "volcanoes and earthquakes",
        ),
        DefaultTopic(id: "famous-explorers", name: "Famous explorers", prompt: "famous explorers"),
        DefaultTopic(id: "human-brain", name: "The human brain", prompt: "the human brain"),
        DefaultTopic(id: "video-game-design", name: "Video game design", prompt: "video game design"),
        DefaultTopic(
            id: "food-culture",
            name: "Food and culture around the world",
            prompt: "food and culture around the world",
        ),
        DefaultTopic(id: "renewable-energy", name: "Renewable energy", prompt: "renewable energy"),
        DefaultTopic(id: "street-art", name: "Street art and graffiti", prompt: "street art and graffiti"),
        DefaultTopic(
            id: "robots-ai",
            name: "Robots and artificial intelligence",
            prompt: "robots and artificial intelligence",
        ),
        DefaultTopic(id: "history-mysteries", name: "Mysteries of history", prompt: "mysteries of history"),
        DefaultTopic(id: "rainforests", name: "Rainforests", prompt: "rainforests"),
        DefaultTopic(id: "science-of-sleep", name: "The science of sleep", prompt: "the science of sleep"),
        DefaultTopic(id: "photography", name: "Photography", prompt: "photography"),
        DefaultTopic(
            id: "teen-challenge-story",
            name: "A teenager facing a challenge",
            prompt: "a short fictional story about a teenager facing a challenge",
        ),
        DefaultTopic(id: "volunteering", name: "Volunteering and community", prompt: "volunteering and community"),
        DefaultTopic(id: "mythology", name: "Mythology", prompt: "mythology"),
        DefaultTopic(
            id: "famous-buildings",
            name: "Architecture of famous buildings",
            prompt: "architecture of famous buildings",
        ),
    ]

    private static let adult = [
        DefaultTopic(
            id: "historic-turning-points",
            name: "History's turning points",
            prompt: "turning points in history",
        ),
        DefaultTopic(id: "psychology-habits", name: "Psychology and habits", prompt: "psychology and habits"),
        DefaultTopic(id: "everyday-economics", name: "Economics in daily life", prompt: "economics in daily life"),
        DefaultTopic(id: "science-breakthroughs", name: "Science breakthroughs", prompt: "scientific breakthroughs"),
        DefaultTopic(id: "philosophy-ethics", name: "Philosophy and ethics", prompt: "philosophy and ethics"),
        DefaultTopic(id: "architecture", name: "Architecture", prompt: "architecture"),
        DefaultTopic(id: "world-literature", name: "World literature", prompt: "world literature"),
        DefaultTopic(id: "nutrition-health", name: "Nutrition and health", prompt: "nutrition and health"),
        DefaultTopic(id: "personal-finance", name: "Personal finance", prompt: "personal finance"),
        DefaultTopic(id: "technology-society", name: "Technology and society", prompt: "technology and society"),
        DefaultTopic(
            id: "literary-fiction",
            name: "Short literary fiction",
            prompt: "a short piece of literary fiction",
        ),
        DefaultTopic(id: "travel-geography", name: "Travel and geography", prompt: "travel and geography"),
        DefaultTopic(id: "history-of-language", name: "The history of language", prompt: "the history of language"),
        DefaultTopic(id: "art-movements", name: "Art movements", prompt: "art movements"),
        DefaultTopic(id: "science-of-sleep", name: "The science of sleep", prompt: "the science of sleep"),
    ]
}
