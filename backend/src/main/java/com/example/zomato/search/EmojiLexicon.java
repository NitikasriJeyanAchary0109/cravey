package com.example.zomato.search;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Food emoji typed as a search ("🍕🔥") are turned into the words they stand for before the query is understood, so they find pizza that is spicy
 * instead of whatever the embedding model happens to place near a picture character. An emoji not listed here means nothing to the search and is
 * dropped; a query left with no words at all finds nothing rather than something arbitrary.
 */
public final class EmojiLexicon {

    private static final Map<String, String> WORDS = new LinkedHashMap<>();

    static {
        // longer sequences first: the red pepper is written as a base character plus a variation selector
        put("🌶️", "spicy"); put("🌶", "spicy"); put("🔥", "spicy");
        put("🍕", "pizza"); put("🍔", "burger"); put("🍟", "fries"); put("🌭", "hot dog"); put("🥪", "sandwich");
        put("🌮", "taco"); put("🌯", "burrito"); put("🫔", "tamale"); put("🥙", "wrap"); put("🧆", "falafel");
        put("🍝", "pasta"); put("🍜", "ramen"); put("🍲", "stew"); put("🍛", "curry"); put("🍚", "rice"); put("🍙", "rice");
        put("🍣", "sushi"); put("🍱", "bento"); put("🥟", "dumpling"); put("🍤", "shrimp"); put("🦐", "shrimp");
        put("🍗", "chicken"); put("🍖", "meat"); put("🥩", "steak"); put("🥓", "bacon"); put("🐟", "fish"); put("🦀", "crab");
        put("🥗", "salad"); put("🥦", "broccoli"); put("🍄", "mushroom"); put("🥑", "avocado"); put("🍅", "tomato");
        put("🧀", "cheese"); put("🥚", "egg"); put("🍳", "egg"); put("🥞", "pancake"); put("🧇", "waffle");
        put("🍞", "bread"); put("🥖", "bread"); put("🥐", "croissant"); put("🥨", "pretzel");
        put("🍰", "cake"); put("🎂", "cake"); put("🧁", "cupcake"); put("🍩", "doughnut"); put("🍪", "cookie");
        put("🍫", "chocolate"); put("🍦", "ice cream"); put("🍨", "ice cream"); put("🍧", "dessert"); put("🍮", "pudding"); put("🍡", "mochi");
        put("🍯", "honey"); put("🍓", "strawberry"); put("🍋", "lemon"); put("🥭", "mango"); put("🍌", "banana");
        put("☕", "coffee"); put("🍵", "tea"); put("🧋", "bubble tea"); put("🥤", "drink"); put("🍹", "cocktail"); put("🍺", "beer");
    }

    private EmojiLexicon() {}

    private static void put(String emoji, String word) { WORDS.put(emoji, word); }

    /** The text with each known emoji replaced by its word, and the invisible joiners emoji sequences carry removed. */
    public static String translate(String text) {
        if (text == null || text.isEmpty()) return text;
        String out = text;
        for (Map.Entry<String, String> e : WORDS.entrySet()) {
            if (out.contains(e.getKey())) out = out.replace(e.getKey(), " " + e.getValue() + " ");
        }
        return out.replace("️", "").replace("‍", "");
    }
}
