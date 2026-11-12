local templates = require("templates")

for _, case in ipairs({
    { { text = ".c1", suffix = "none" }, ".c1" },
    { { text = ".c1", suffix = "space" }, ".c1 " },
    { { text = ".c2", suffix = "newline" }, ".c2\n" },
    { { text = ".words", suffix = "blank_line" }, ".words\n\n" },
    { { text = "my text\nnext line", suffix = "none" }, "my text\nnext line" },
    { { text = "  日本語 🐕\n", suffix = "space" }, "  日本語 🐕\n " },
    { { text = " \n ", suffix = "none" }, " \n " },
}) do
    assert(templates.validate({ case[1] }))
    assert(templates.insertionText(case[1]) == case[2])
end
assert(templates.validate({}))
for _, value in ipairs({
    false, 5, "bad", { "bad" }, { false }, { {} },
    { { text = "", suffix = "space" } },
    { { text = false, suffix = "space" } },
    { { text = 42, suffix = "space" } },
    { { text = "x", suffix = "unknown" } },
    { { text = "x" } },
    { { text = "x", suffix = {} } },
    { [2] = { text = "x", suffix = "none" } },
    { [0] = { text = "x", suffix = "none" } },
    { [1.5] = { text = "x", suffix = "none" } },
    { extra = { text = "x", suffix = "none" } },
}) do
    local ok, err = templates.validate(value)
    assert(not ok and type(err) == "string" and #err > 0)
end
assert(not templates.validate(nil))
local text, err = templates.insertionText({ text = "x", suffix = "bad" })
assert(text == nil and type(err) == "string")
print("templates_test: passed")
