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
# function age_check(val::AbstractString; max_age::Int = 80)
#     # parse the string into an integer
#     a = try
#         parse(Int, val)
#     catch
#         return nothing       # if it isn’t an integer, drop/blank it
#     end

#     # if over max_age, return nothing → cell becomes blank
#     # downstream, you can post-filter all rows where "Age" is blank
#     return a <= max_age ? val : nothing
# end

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
# UPDATED AGE CHECK - handles DOB columns too 
function age_check(val::AbstractString; max_age::Int = 80,
                   today::Date = Dates.today(),
                   date_formats::Tuple{Vararg{AbstractString}} = (
                       "yyyy-mm-dd", "mm/dd/yyyy", "m/d/yyyy",
                       "mm/dd/yy", "m/d/yy"
                   ))
    sval = strip(val)

    # Try integer age
    a = try
        parse(Int, sval)
    catch
        nothing
    end
    if a !== nothing
        return (0 ≤ a ≤ max_age) ? string(a) : nothing
    end

    # Try DOB
    dob = nothing
    for fmt in date_formats
        try
            dob = Date(sval, dateformat"$fmt"); break
        catch
        end
    end
    if dob === nothing || dob > today
        return nothing
    end

    age = year(today) - year(dob) - ((month(today), day(today)) < (month(dob), day(dob)) ? 1 : 0)
    return (0 ≤ age ≤ max_age) ? string(age) : nothing
end

# Helpful overloads
age_check(a::Integer; max_age::Int = 80) = (0 ≤ a ≤ max_age) ? string(a) : nothing

function age_check(dob::Date; max_age::Int = 80, today::Date = Dates.today())
    age = year(today) - year(dob) - ((month(today), day(today)) < (month(dob), day(dob)) ? 1 : 0)
    return (0 ≤ age ≤ max_age) ? string(age) : nothing
end

age_check(::Missing; kwargs...) = nothing   # keep this for DataFrames broadcasting
age_check(::Nothing; kwargs...) = nothing   # optional—only if you may pass `nothing`

end # module