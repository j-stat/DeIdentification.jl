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
# Keep ages ≤ max_age; blank (> max_age) or non-parsable as `nothing`
# Works with DOB variable 
# Has a default reference year of today that can be overidden 
"""
    age_check(dob; max_age::Int=90, ref_year::Int=year(today()),
                 fmt::DateFormat = dateformat"yyyy-mm-dd", cap::Bool=true)

Compute age from a date of birth (DOB) relative to `ref_year` (age as of Dec 31 of that year).
If `cap` is true and age exceeds `max_age`, reset the DOB's year to `ref_year - max_age`
(keeping month/day where possible) so the resulting age equals `max_age`.

Arguments
- `dob`: `Date`, `DateTime`, or `String` (ISO 8601 by default: `yyyy-mm-dd`)
- `max_age`: age cutoff (default 90)
- `ref_year`: reference year used to compute age (default current year)
- `fmt`: date format used to parse `String` inputs (default ISO 8601)
- `cap`: whether to cap ages above `max_age` by adjusting birth year (default true)

Returns a `NamedTuple`:
- `age::Int`        — computed (possibly capped) age
- `dob_out::Date`   — original DOB or adjusted DOB if capped
- `capped::Bool`    — whether a cap/adjustment was applied

Invalid/future DOBs relative to the reference date return `nothing`.
"""
function age_check(dob; max_age::Int=90, ref_year::Int=year(today()),
                      fmt::DateFormat = dateformat"yyyy-mm-dd", cap::Bool=true)

    refdate = Date(ref_year, 12, 31)

    # Normalize input to Date
    d::Date = if dob isa Date
        dob
    elseif dob isa DateTime
        Date(dob)
    elseif dob isa AbstractString
        try
            Date(strip(dob), fmt)
        catch
            return nothing
        end
    else
        return nothing
    end

    # Reject future DOBs relative to the reference date
    if d > refdate
        return nothing
    end

    # Compute age as of refdate
    age = _age_as_of(d, refdate)

    if cap && age > max_age
        newyear = ref_year - max_age
        d_cap = _rebase_birthyear(d, newyear)
        # Recompute for safety (should equal max_age)
        age_cap = _age_as_of(d_cap, refdate)
        return (age = age_cap, dob_out = d_cap, capped = true)
    else
        return (age = age, dob_out = d, capped = false)
    end
end

# --- Helpers ---

# Age as of a given reference date
function _age_as_of(dob::Date, refdate::Date)
    a = year(refdate) - year(dob)
    if (month(refdate), day(refdate)) < (month(dob), day(dob))
        a -= 1
    end
    return a
end

# Change the birth year but keep month/day when possible.
# Handles Feb 29 by clamping to last day of month in non-leap years.
function _rebase_birthyear(dob::Date, newyear::Int)
    m = month(dob)
    d = min(day(dob), day(lastdayofmonth(Date(newyear, m, 1))))
    return Date(newyear, m, d)
end



# age_check(x; max_age::Int = 90) = _age_check_any(x, max_age)

# # Methods
# # Keep ages ≤ max_age; blank (> max_age) or non-parsable as `nothing`
# age_check(x; max_age::Int = 40) = _age_check_any(x, max_age)

# # Methods
# _age_check_any(::Missing, ::Int) = nothing

# function _age_check_any(x::AbstractString, max_age::Int)
#     s = strip(x)
#     p = tryparse(Int, s)
#     p === nothing ? nothing : (p <= max_age ? p : nothing)
# end

# function _age_check_any(x::Real, max_age::Int)
#     a = Int(floor(x))
#     return (0 ≤ a ≤ max_age) ? a : nothing
# end







