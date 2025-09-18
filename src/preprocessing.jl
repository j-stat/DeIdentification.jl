using Dates

# YEAR ONLY - take in a date string and extract just the year component
function year_only(val::AbstractString)
    raw = strip(val)
    if isempty(raw)
        return nothing
    end

    # normalize common ISO timezone suffixes that Dates can't parse
    norm = replace(raw,
        r"Z$" => "",
        r"([+-]\d{2}):?(\d{2})$" => s"\1\2"  # +05:30 or +0530 -> +0530
    )

    # Try DateTime formats first (covers your med.csv like 2017-02-27T08:00:00.0)
    dt_formats = DateFormat.([
        "y-m-dTH:M:S.s",     # 2017-02-27T08:00:00.0
        "y-m-dTH:M:S",       # 2017-02-27T08:00:00
        "y-m-d H:M:S.s",     # 2017-02-27 08:00:00.0
        "y-m-d H:M:S",       # 2017-02-27 08:00:00
    ])
    for f in dt_formats
        try
            return string(year(DateTime(norm, f)))
        catch
        end
    end

    # Try Date-only formats
    d_formats = DateFormat.([
        "yyyy-mm-dd",
        "yyyy/mm/dd",
        "yyyy.mm.dd",
        "mm/dd/yyyy",
        "dd-mm-yyyy",
        "yyyymmdd",
    ])
    for f in d_formats
        try
            return string(year(Date(norm, f)))
        catch
        end
    end

    # Plain 4-digit year anywhere in the string (safe fallback)
    m = match(r"\b(1[5-9]\d{2}|20\d{2}|21\d{2})\b", raw)
    return m === nothing ? nothing : m.captures[1]
end

# AGE CHECK - check if input is a number and is below max age, if over max age value set to nothing 
# keep values ≤ max_age, blank out (missing) if > max_age
# Keep ages ≤ max_age; set > max_age (or non-parsable) to `missing`.
# Works for strings like "52", numbers like 52, and `missing`.
age_check(x; max_age::Int = 40) = _age_check_any(x, max_age)

# ---- methods ----
_age_check_any(::Missing, ::Int) = missing

# Strings: strip, parse, compare
function _age_check_any(x::AbstractString, max_age::Int)
    s = strip(x)
    a = tryparse(Int, s)
    a === nothing ? missing : (a <= max_age ? a : missing)
end

# Numerics: coerce to Int (using floor to be safe), compare
function _age_check_any(x::Real, max_age::Int)
    a = Int(floor(x))
    return (0 ≤ a ≤ max_age) ? a : missing
end


# # TESTS 
# function test_year_only()
#     samples = [
#         "2017-02-27T08:00:00.0",
#         "2017-02-27T08:00:00",
#         "2017-02-27 08:00:00",
#         "2017-02-27",
#         "07/04/2020",
#         "2021",
#         "bad-data",
#         ""
#     ]

#     println("Testing year_only function:")
#     for s in samples
#         println("Input: ", s, "  =>  Output: ", year_only(s))
#     end
# end

# # Simple test passthrough
# function echo_test(val)
#     return string("ECHO_", val)
# end

