using Dates

# Transformation functions for use with deidentification package 

# NOTE: To add a new transformation for users, just create a function below; 
# just make sure your function returns a value, e.g., returns the value you want or, if fails, returns nothing 

# YEAR ONLY - take in a date string and extract just the year component

# Public API (multi-dispatch) 
year_only(::Nothing) = nothing
year_only(::Missing) = nothing
year_only(d::Date) = string(year(d))
year_only(dt::DateTime) = string(year(dt))

# Accept 4-digit integer years (e.g., 2017). Others return nothing.
function year_only(x::Integer)
    (1000 <= x <= 9999) ? string(x) : nothing
end

# Floats are not meaningful years; return nothing
year_only(::Real) = nothing

# Strings: try several formats (incl. ISO-8601 with fractional seconds)
function year_only(val::AbstractString)
    raw = strip(val)
    isempty(raw) && return nothing

    # If the string is exactly a 4-digit year, accept directly.
    if occursin(r"^\d{4}$", raw)
        return raw
    end

    # Normalize common ISO timezone suffixes that Julia Dates can't parse:
    # - trailing "Z"
    # - trailing "+hh:mm" or "-hh:mm" (or without the colon)
    norm = replace(raw,
        r"Z$" => "",
        r"([+-]\d{2}:?\d{2})$" => "",
    )

    # Try a bunch of common formats (order matters; most specific first)
    formats = DateFormat[
        dateformat"yyyy-mm-ddTHH:MM:SS.s",   # 2017-02-27T08:00:00.0 / .123 etc.
        dateformat"yyyy-mm-ddTHH:MM:SS",     # 2017-02-27T08:00:00
        dateformat"yyyy-mm-ddTHH:MM",        # 2017-02-27T08:00
        dateformat"yyyy-mm-dd HH:MM:SS.s",   # 2017-02-27 08:00:00.0
        dateformat"yyyy-mm-dd HH:MM:SS",     # 2017-02-27 08:00:00
        dateformat"yyyy/mm/dd HH:MM:SS",     # 2017/02/27 08:00:00
        dateformat"mm/dd/yyyy HH:MM:SS",     # 02/27/2017 08:00:00
        dateformat"dd-mm-yyyy HH:MM:SS",     # 27-02-2017 08:00:00

        # Date-only variants
        dateformat"yyyy-mm-dd",
        dateformat"yyyy/mm/dd",
        dateformat"yyyy.mm.dd",
        dateformat"mm/dd/yyyy",
        dateformat"dd-mm-yyyy",
        dateformat"mm-dd-yyyy",
        dateformat"dd/mm/yyyy",

        # Year + month (assume day 01)
        dateformat"yyyy-mm",
        dateformat"yyyy/mm",
        dateformat"mm-yyyy",
        dateformat"mm/yyyy",

        # Year only
        dateformat"yyyy",
    ]

    for fmt in formats
        try
            # Prefer Date when format is date-only; DateTime when it has time tokens
            if occursin(r"[HMS]", string(fmt))
                dt = DateTime(norm, fmt)
                return string(year(dt))
            else
                d = Date(norm, fmt)
                return string(year(d))
            end
        catch
            # try next
        end
    end

    # As a last resort, extract the first 4-digit year-looking token in the string.
    if m = match(r"\b(\d{4})\b", raw); m !== nothing
        return m.captures[1]
    end

    return nothing
end

# AGE CHECK - check if input is a number and is below max age, if over max age value set to nothing 
function age_check(val::AbstractString; max_age::Int = 80)
    # parse the string into an integer
    a = try
        parse(Int, val)
    catch
        return nothing       # if it isn’t an integer, drop/blank it
    end

    # if over max_age, return nothing → cell becomes blank
    # downstream, you can post-filter all rows where "Age" is blank
    return a <= max_age ? val : nothing
end
