using Dates

# -------- Public API (multi-dispatch) --------
year_only(::Nothing) = nothing
year_only(::Missing) = nothing
year_only(d::Date) = string(year(d))
year_only(dt::DateTime) = string(year(dt))

# Accept 4-digit integer years (e.g., 2017). Others return nothing.
function year_only(x::Integer)
    (1000 <= x <= 9999) ? string(x) : nothing
end

# Floats and other reals are not meaningful years; return nothing
year_only(::Real) = nothing

# Strings: try several formats (incl. ISO-8601 with fractional seconds)
function year_only(val::AbstractString)
    raw = strip(val)
    isempty(raw) && return nothing

    # If the string is exactly a 4-digit year, accept directly.
    if occursin(r"^\d{4}$", raw)
        return raw
    end

    # Normalize common ISO timezone suffixes that Julia Dates can't parse
    norm = replace(raw,
        r"Z$" => "",
        r"([+-]\d{2}):?(\d{2})$" => s"\1\2"  # turn +05:30 or +0530 into +0530
    )

    # Try a sequence of DateTime then Date formats
    dt_formats = DateFormat.([
        "yyyy-mm-ddTHH:MM:SS.sss",
        "yyyy-mm-ddTHH:MM:SS",
        "yyyy-mm-dd HH:MM:SS.sss",
        "yyyy-mm-dd HH:MM:SS",
        "yyyy/mm/dd HH:MM:SS",
        "mm/dd/yyyy HH:MM:SS",
    ])

    for f in dt_formats
        try
            return string(year(DateTime(norm, f)))
        catch
        end
    end

    date_formats = DateFormat.([
        "yyyy-mm-dd", "yyyy/mm/dd", "yyyy.mm.dd",
        "mm/dd/yyyy", "dd-mm-yyyy", "dd.mm.yyyy",
        "yyyymmdd"
    ])

    for f in date_formats
        try
            return string(year(Date(norm, f)))
        catch
        end
    end

    # Last resort: grab the first plausible 4-digit year anywhere in the string
    m = match(r"\b(1[5-9]\d{2}|20\d{2}|21\d{2})\b", raw)
    return m === nothing ? nothing : m.captures[1]
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
