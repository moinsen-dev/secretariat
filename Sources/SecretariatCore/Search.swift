import Foundation

/// Forgiving search: case, accents and separators (`_ - / . :` and spaces inside a word) don't count,
/// so `CF_FI`, `cf-fix` and `cffix` all find `CF_FIX_TOKEN`. Several words narrow the result.
/// Words that match nothing at all are ignored, so a pasted sentence such as
/// "Delete CF_FIX_TOKEN from the profile moinsen-edge" still finds its item.
public enum Search {
    /// Lower case, accents folded, only letters and digits.
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return String(String.UnicodeScalarView(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    /// The query's words, normalized; very short words drop out when longer ones are there.
    public static func terms(_ query: String) -> [String] {
        let words = query.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" }).map { normalize(String($0)) }.filter { !$0.isEmpty }
        let long = words.filter { $0.count >= 3 }
        var seen = Set<String>()
        return (long.isEmpty ? words : long).filter { seen.insert($0).inserted }
    }

    /// The entries that match `query`, in their original order. `text` gives the strings an entry is found by.
    /// All words must match; if no entry has them all, the entries with the rarest words come first.
    public static func filter<T>(_ entries: [T], query: String, text: (T) -> [String]) -> [T] {
        let terms = terms(query)
        guard !terms.isEmpty else { return entries }
        // A separator between strings keeps a word from matching across two of them.
        let haystacks = entries.map { text($0).map(normalize).joined(separator: " ") }
        let frequency = terms.map { term in haystacks.filter { $0.contains(term) }.count }
        let useful = zip(terms, frequency).filter { $0.1 > 0 }
        guard !useful.isEmpty else { return [] }

        let all = entries.indices.filter { i in useful.allSatisfy { haystacks[i].contains($0.0) } }
        if !all.isEmpty { return all.map { entries[$0] } }

        // No entry has every word: weigh each word by how rare it is and how well it fits
        // (a whole name beats the start of a word beats a fragment), then keep the clear leaders.
        let scores = entries.map { entry in
            let strings = text(entry)
            return useful.reduce(0.0) { sum, pair in sum + fit(pair.0, in: strings) / Double(pair.1) }
        }
        let best = scores.max() ?? 0
        return entries.indices.filter { scores[$0] > 0 && scores[$0] >= best / 2 }.map { entries[$0] }
    }

    /// 3: the term is a whole string or word; 2: it starts one; 1: it stands somewhere inside; 0: nowhere.
    static func fit(_ term: String, in strings: [String]) -> Double {
        var best = 0.0
        for string in strings {
            let whole = normalize(string)
            guard whole.contains(term) else { continue }
            let words = string.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { normalize(String($0)) }
            if whole == term || words.contains(term) { return 3 }
            best = max(best, whole.hasPrefix(term) || words.contains { $0.hasPrefix(term) } ? 2 : 1)
        }
        return best
    }

    /// Every item's bindings as "owner" and "VARIABLE" pairs, across projects and targets; build it once per search.
    public static func bindings(_ configuration: Configuration) -> [UUID: [(owner: String, variable: String)]] {
        var index: [UUID: [(owner: String, variable: String)]] = [:]
        for (owner, bindings) in configuration.profiles.map({ ($0.name, $0.bindings) }) + configuration.targets.map({ ($0.name, $0.bindings) }) {
            for binding in bindings { index[binding.itemID, default: []].append((owner, binding.variable)) }
        }
        return index
    }

    /// What an item is found by: path, kind, source, field names and labels, identifier values,
    /// and every variable that binds it in a project or target together with that project's or target's name.
    public static func itemText(_ item: ItemMeta, bindings: [UUID: [(owner: String, variable: String)]], kindTitle: String = "", fieldLabels: [String] = []) -> [String] {
        var text = [item.path, item.kind, kindTitle, item.source] + fieldLabels
        for field in item.fields {
            text.append(field.name)
            if let value = field.value { text.append(value) }
        }
        for bound in bindings[item.id] ?? [] { text.append(bound.owner); text.append(bound.variable) }
        return text
    }

    /// The bindings of `item` whose variable the query names, as "VARIABLE in project" for the result row.
    public static func boundAs(_ item: ItemMeta, query: String, bindings: [UUID: [(owner: String, variable: String)]]) -> [String] {
        let terms = terms(query)
        guard !terms.isEmpty else { return [] }
        return (bindings[item.id] ?? []).filter { bound in
            let variable = normalize(bound.variable)
            return terms.contains { variable.contains($0) }
        }.map { "\($0.variable) in \($0.owner)" }
    }
}
