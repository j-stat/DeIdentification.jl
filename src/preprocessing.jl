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
    age_check(val; refdate=today())

Return integer age as of `refdate` (default: today) for a birth date in `val`.
Accepts:
- `YYYY-MM-DD`, `YYYY/MM/DD`
- DateTime variants like `YYYY-MM-DDTHH:MM:SS(.sss)` (with optional `Z` or `+hh:mm`)
- `Date`, `DateTime`
- Excel serial numbers (days since 1899-12-30)

Returns `nothing` if parsing fails.
"""
function age_check(val; refdate::Date = today(), max_age::Int = 60, min_age::Int = 0)
    if val === missing || val === nothing
        return nothing
    elseif val isa Date
        dob = val
    elseif val isa DateTime
        dob = Date(val)
    elseif val isa Integer || val isa AbstractFloat
        # Excel serial origin 1899-12-30 (Windows)
        try
            dob = Date(1899,12,30) + Day(floor(Int, val))
        catch
            return nothing
        end
    elseif val isa AbstractString
        s = strip(String(val))
        isempty(s) && return nothing
        s = replace(s, r"Z$" => "", r"([+-]\d{2}):?(\d{2})$" => s"\1\2")

        dob_parsed = nothing
        for fmt in (dateformat"y-m-d", dateformat"Y-m-d", dateformat"y/m/d",
                    dateformat"m/d/y", dateformat"m/d/Y")
            try
                dob_parsed = Date(s, fmt); break
            catch
            end
        end
        if dob_parsed === nothing
            for fmt in (DateFormat("y-m-dTH:M:S.s"), DateFormat("y-m-dTH:M:S"),
                        DateFormat("y-m-d H:M:S.s"), DateFormat("y-m-d H:M:S"))
                try
                    dob_parsed = Date(DateTime(s, fmt)); break
                catch
                end
            end
        end
        dob_parsed === nothing && return nothing
        dob = dob_parsed
    else
        return nothing
    end

    a = year(refdate) - year(dob)
    if (month(refdate), day(refdate)) < (month(dob), day(dob))
        a -= 1
    end
    # clamp between min_age and max_age
    return clamp(a, min_age, max_age)
end

function age_check(col::AbstractVector; refdate::Date = today(), max_age::Int = 90, min_age::Int = 0, missing_as = nothing)
    out = Vector{Union{Missing, Int}}(undef, length(col))
    @inbounds for i in eachindex(col)
        v = age_check(col[i]; refdate=refdate, max_age=max_age, min_age=min_age)
        out[i] = v === nothing ? (ismissing(missing_as) ? missing : missing_as) : v
    end
    return out
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







