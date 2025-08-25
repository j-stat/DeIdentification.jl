using Dates

# Keep this in Main (via include), so the eval'd transform can find it.
function year_only(val::AbstractString)
    raw = strip(val)
    isempty(raw) && return ""
    # fast-path: 4-digit year
    if occursin(r"^\d{4}$", raw)
        return raw
    end
    # normalize common ISO suffixes
    norm = replace(raw, r"Z$" => "", r"([+-]\d{2}:?\d{2})$" => "")
    for fmt in (dateformat"yyyy-mm-ddTHH:MM:SS.s",
                dateformat"yyyy-mm-ddTHH:MM:SS",
                dateformat"yyyy-mm-dd",
                dateformat"mm/dd/yyyy",
                dateformat"dd-mm-yyyy",
                dateformat"yyyy/mm/dd",
                dateformat"yyyy.mm.dd")
        try
            return string(year(DateTime(norm, fmt)))
        catch
            try
                return string(year(Date(norm, fmt)))
            catch
            end
        end
    end
    if m = match(r"\b(\d{4})\b", raw); m !== nothing
        return m.captures[1]
    end
    return ""
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
