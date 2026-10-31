package com.example.zomato.search;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class EmojiLexiconTest {

    private final QueryParser parser = new QueryParser();

    @Test
    void knownEmojiBecomeTheirWords() {
        assertEquals("pizza", EmojiLexicon.translate("🍕").trim());
        String both = EmojiLexicon.translate("🌶️🍕");
        assertTrue(both.contains("spicy") && both.contains("pizza"), both);
        assertFalse(EmojiLexicon.translate("🌶️").contains("️"), "the variation selector is gone");
        assertEquals("plain text", EmojiLexicon.translate("plain text"));
        assertNull(EmojiLexicon.translate(null));
    }

    @Test
    void theParserReadsEmojiAsFoodAndFlavor() {
        var p = parser.parse("🍕🔥");
        assertEquals("pizza spicy", p.normalized());
        assertTrue(p.flavors().stream().anyMatch(f -> f.id().equals("spicy")));
        assertEquals("pizza", parser.parse("i want 🍕 please").normalized());
        assertEquals("🍕🔥", p.original(), "the original is kept for the search log");
    }

    @Test
    void anEmojiWithNoMeaningLeavesNoWords() {
        assertFalse(HybridSearchService.hasWords(parser.parse("😀").normalized()));
        assertFalse(HybridSearchService.hasWords(parser.parse("🎉 🎉").normalized()));
        assertTrue(HybridSearchService.hasWords(parser.parse("😀 pizza").normalized()));
        assertTrue(HybridSearchService.hasWords("route 66"), "digits count as words");
    }

    @Test
    void hungoverIsAComfortCraving() {
        for (String q : new String[]{"hungover", "hangover", "so hungover"}) {
            assertTrue(parser.parse(q).flavors().stream().anyMatch(f -> f.id().equals("comfort")), q);
        }
    }
}
