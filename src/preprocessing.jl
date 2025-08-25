using Dates

# be tolerant to missings/nothings
year_only(::Missing) = nothing
year_only(::Nothing) = nothing

# main string-based extractor
function year_only(val::AbstractString)
    raw = strip(String(val))
    isempty(raw) && return nothing

    # fast path: plain 4-digit year
    if occursin(r"^\d{4}$", raw)
        return raw
    end

    # normalize common timezone suffixes so Dates can parse more cases
    norm = replace(raw,
        r"Z$" => "",
        r"([+-]\d{2}):?(\d{2})$" => s"\1\2",  # +05:30 or +0530 -> +0530
    )

    # try your project’s timestamp first (matches med.csv & your YAML date_format)
    try
        return string(year(DateTime(norm, DateFormat("y-m-dTH:M:S.s"))))
    catch
    end

    # try nearby ISO/time variants
    for fmt in (
        DateFormat("y-m-dTH:M:S"),
        DateFormat("y-m-d H:M:S.s"),
        DateFormat("y-m-d H:M:S"),
    )
        try
            return string(year(DateTime(norm, fmt)))
        catch
        end
    end

    # try date-only formats
    for fmt in (
        DateFormat("yyyy-mm-dd"),
        DateFormat("yyyy/mm/dd"),
        DateFormat("yyyy.mm.dd"),
        DateFormat("mm/dd/yyyy"),
        DateFormat("dd-mm-yyyy"),
        DateFormat("yyyymmdd"),
    )
        try
            return string(year(Date(norm, fmt)))
        catch
        end
    end

    # safe last resort: first plausible 4-digit year
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
