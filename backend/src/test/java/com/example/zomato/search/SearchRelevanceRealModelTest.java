package com.example.zomato.search;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Real model: the way people actually type. Emoji mean food, "hungover" means comfort food, and a named food comes before things that are merely
 * close to it ("cheesy burger" is answered by burgers before mac and cheese). Skipped when the model is not installed.
 */
@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:relevance_real;DB_CLOSE_DELAY=-1;MODE=PostgreSQL")
class SearchRelevanceRealModelTest {

    @Autowired SeedDishLoader seeds;
    @Autowired HybridSearchService search;

    @BeforeAll
    static void requireModel() {
        assumeTrue(Files.isRegularFile(Path.of("models/bge-small-en-v1.5/model.onnx")), "model not installed, skipping");
    }

    private HybridSearchService.Result run(String q, Boolean veg) {
        seeds.load(true);
        var r = search.search(new HybridSearchService.Request(q, 10, veg, null, false));
        assertEquals("HYBRID", r.mode(), "this has to run on the real model");
        return r;
    }

    private static List<String> names(HybridSearchService.Result r) { return r.hits().stream().map(h -> h.doc().name()).toList(); }

    @Test
    void hungoverFindsComfortFoodInsteadOfNothing() {
        var r = run("hungover", null);
        assertFalse(r.hits().isEmpty());
        assertTrue(r.parsed().flavors().stream().anyMatch(f -> f.id().equals("comfort")), "read as a comfort craving");
        assertTrue(names(r).stream().anyMatch(n -> n.contains("Ramen") || n.contains("Lasagna") || n.contains("Alfredo") || n.contains("Mac and Cheese")), names(r).toString());
        assertFalse(run("hangover", null).hits().isEmpty(), "either spelling");
    }

    @Test
    void foodEmojiMeanTheFoodAndTheFirePepperMeansSpicy() {
        var r = run("🍕🔥", null);
        assertEquals("pizza spicy", r.parsed().normalized());
        assertTrue(names(r).get(0).contains("Pizza"), names(r).toString());
        assertTrue(names(r).stream().limit(3).allMatch(n -> n.contains("Pizza") || n.contains("Calzone")), "pizzas come first: " + names(r));
        assertTrue(names(run("🍕", null)).stream().allMatch(n -> n.contains("Pizza") || n.contains("Calzone")), "just the pizza emoji finds just pizza");
    }

    @Test
    void anEmojiThatMeansNoFoodFindsNothingRatherThanSomethingArbitrary() {
        var r = run("😀", null);
        assertEquals(0, r.total());
        assertTrue(r.hits().isEmpty());
        assertTrue(run("🎉🎉", null).hits().isEmpty());
    }

    @Test
    void whenNoDishHasBothWordsTheKindOfDishNamedByTheLastWordComesFirst() {
        var r = run("truffle ramen", null);
        assertEquals(4, names(r).stream().limit(4).filter(n -> n.contains("Ramen")).count(), "the ramen dishes lead: " + names(r));
        assertTrue(names(r).indexOf("Chili Chocolate Truffle") > 3, "a truffle dessert is not a ramen: " + names(r));
    }

    @Test
    void aNamedFoodComesBeforeThingsThatOnlyShareAFlavor() {
        var veg = run("cheesy burger", true);
        assertEquals("Veggie Smash Burger", names(veg).get(0), "the only vegetarian burger leads: " + names(veg));
        var all = run("cheesy burger", null);
        assertTrue(names(all).stream().limit(4).allMatch(n -> n.contains("Burger") || n.contains("burger")), "burgers lead: " + names(all));
        assertTrue(names(all).containsAll(List.of("Mac and Cheese Bites")), "cheesy things still follow");
        var noodles = run("spicy noodles", null);
        assertTrue(names(noodles).stream().limit(3).anyMatch(n -> n.contains("Ramen") || n.equals("Pad Thai")), names(noodles).toString());
    }

    @Test
    void aTypoStillFindsTheDumplingDishes() {
        // the Gulab Jamun really is described as "milk dumplings", so it belongs with the gyoza
        assertEquals(names(run("dumpling", null)), names(run("dumplins", null)));
        assertTrue(names(run("dumplins", null)).contains("Gyoza (6 pc)"));
    }

    @Test
    void ordinaryAnswersAreUnchanged() {
        assertEquals(List.of("Beef Birria Tacos", "Tacos al Pastor"), names(run("birria tacos", null)));
        assertEquals("Mac and Cheese Bites", names(run("mac and cheese", null)).get(0));
        assertTrue(names(run("pasta", null)).containsAll(List.of("Spaghetti Carbonara", "Fettuccine Alfredo")));
        assertTrue(names(run("something sweet", null)).stream().anyMatch(n -> n.contains("Mochi") || n.contains("Dorayaki")));
    }
}
