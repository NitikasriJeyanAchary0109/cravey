package com.example.zomato;

import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;

import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * Test cleanup shared by classes that run against the same in-memory database in whatever order the build picks.
 * A class that deletes orders must also delete everything pointing at them (payments, deliveries, ratings, items),
 * including rows an earlier class left behind, so the dependents are found from the schema rather than listed by hand.
 */
public final class TestData {
    private TestData() {}

    /** H2 only: empties orders and every table with a foreign key to it. */
    public static void wipeOrders(JdbcTemplate jdbc) {
        jdbc.execute((ConnectionCallback<Void>) con -> {
            try (Statement st = con.createStatement()) {
                List<String> dependents = new ArrayList<>();
                try (ResultSet rs = st.executeQuery(
                        "SELECT DISTINCT fk.TABLE_NAME FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc "
                                + "JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS fk ON fk.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA AND fk.CONSTRAINT_NAME = rc.CONSTRAINT_NAME "
                                + "JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ON pk.CONSTRAINT_SCHEMA = rc.UNIQUE_CONSTRAINT_SCHEMA AND pk.CONSTRAINT_NAME = rc.UNIQUE_CONSTRAINT_NAME "
                                + "WHERE UPPER(pk.TABLE_NAME) = 'ORDERS'")) {
                    while (rs.next()) dependents.add(rs.getString(1));
                }
                st.execute("SET REFERENTIAL_INTEGRITY FALSE");
                try {
                    for (String table : dependents) st.executeUpdate("DELETE FROM \"" + table + "\"");
                    st.executeUpdate("DELETE FROM orders");
                } finally {
                    st.execute("SET REFERENTIAL_INTEGRITY TRUE");
                }
            }
            return null;
        });
    }
}
