using Dates

# ----- YEAR ONLY - take in a date string and extract just the year component
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

# ------ AGE CHECK - check if input is a number and is below max age, if over max age value set to nothing 
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
# Return YEAR ONLY (Int) from DOB, capped so age <= max_age as of refdate.
function age_check(val; refdate::Any = today(), max_age::Int = 90, debug::Bool=false)
    # --- early exits ---
    if val === missing || val === nothing
        return nothing
    end

    # --- normalize refdate to a Date ---
    if refdate isa DateTime
        refdate = Date(refdate)
    elseif refdate isa AbstractString
        s = strip(String(refdate))
        if (m = match(r"^Date\((\d{4})-(\d{1,2})-(\d{1,2})\)$", s)) !== nothing
            refdate = Date(parse(Int, m.captures[1]), parse(Int, m.captures[2]), parse(Int, m.captures[3]))
        elseif (m = match(r"^Date\((\d{4}),\s*(\d{1,2}),\s*(\d{1,2})\)$", s)) !== nothing
            refdate = Date(parse(Int, m.captures[1]), parse(Int, m.captures[2]), parse(Int, m.captures[3]))
        elseif (m = match(r"^Date\(\"(\d{4}-\d{1,2}-\d{1,2})\"\)$", s)) !== nothing
            refdate = Date(m.captures[1])
        else
            try
                refdate = Date(s)  # ISO "YYYY-MM-DD"
            catch
                error("age_check: refdate must resolve to a Date; got \"$s\"")
            end
        end
    elseif !(refdate isa Date)
        error("age_check: refdate must be Date/DateTime/String; got $(typeof(refdate))")
    end

    # --- parse input value to a Date (robust) ---
    dob::Union{Nothing,Date} = nothing

    if val isa Date
        dob = val

    elseif val isa DateTime
        dob = Date(val)

    elseif val isa Integer || val isa AbstractFloat
        # If it "looks like a year" (e.g., 1972), treat as DOB year.
        v = Int(floor(val))
        yr = year(refdate)
        if 1500 <= v <= (yr + 1)  # upper bound
            dob = Date(v, 12, 31) # use end-of-year so things stay capped 
        else
            # Excel serial 
            try
                dob = Date(1899,12,30) + Day(v)
            catch
                return nothing
            end
        end

    elseif val isa AbstractString
        s = strip(String(val))
        isempty(s) && return nothing

        # If it's exactly a 4-digit year, treat as DOB year.
        if (m = match(r"^\s*(\d{4})\s*$", s)) !== nothing
            y = parse(Int, m.captures[1])
            if 1500 <= y <= (year(refdate) + 1)
                dob = Date(y, 12, 31)   # end-of-year keeps boundary years uncapped
            end
        end

        # If not already resolved, try DateTime formats
        if dob === nothing
            s = replace(s, r"Z$" => "", r"([+-]\d{2}):?(\d{2})$" => s"\1\2")  # normalize TZ
            for fmt in (dateformat"y-m-d", dateformat"Y-m-d", dateformat"y/m/d",
                        dateformat"m/d/y", dateformat"m/d/Y")
                try; dob = Date(s, fmt); break; catch; end
            end
            if dob === nothing
                for fmt in (DateFormat("y-m-dTH:M:S.s"), DateFormat("y-m-dTH:M:S"),
                            DateFormat("y-m-d H:M:S.s"), DateFormat("y-m-d H:M:S"))
                    try; dob = Date(DateTime(s, fmt)); break; catch; end
                end
            end
        end

    else
        return nothing
    end

    dob === nothing && return nothing

    # --- cap: anyone OLDER than max_age as of refdate moves to cap_year ---
    cap_line = refdate - Year(max_age)   # e.g., 2000-10-07 - 20y = 1980-10-07
    cap_year = year(cap_line)
    will_cap = dob < cap_line
    y = will_cap ? cap_year : year(dob)

    if debug
        @info "age_check" (; val, dob, refdate, max_age, cap_line, cap_year, will_cap, out=y)
    end

    return y
end

# ---- AGE CHECK function for numeric age 
function age_check_numeric(age; max_age::Int=90)
    # Normalize to Int
    a = if age isa Missing
        return (age = missing, capped = false)
    elseif age isa Int
        age
elseif age isa Real
    if isnan(age)
        return nothing
    else
        return Int(floor(age))
    end
    elseif age isa AbstractString
        try
            Int(floor(parse(Float64, strip(age))))
        catch
            return nothing
        end
    else
        return nothing
    end

    # Reject negatives
    if a < 0
        return nothing
    end

    # Cap if needed
    if a > max_age
        return (age = max_age, capped = true)
    else
        return (age = a, capped = false)
    end
end








