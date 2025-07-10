using Dates

# Transformation functions for use with deidentification package 

# NOTE: To add a new transformation for users, just create a function below; 
# just make sure your function returns a value, e.g., returns the value you want or, if fails, returns nothing 

# YEAR ONLY - take in a date string and extract just the year component
function year_only(val::AbstractString)
    raw = strip(val)
    if isempty(raw)
        return nothing
    end

    # List of formats to try
    formats = [
        dateformat"yyyy-mm-dd",
        dateformat"mm/dd/yyyy",
        dateformat"dd-mm-yyyy",
        dateformat"yyyy/mm/dd",
        dateformat"yyyy.mm.dd",
    ]

    for fmt in formats
        try
            dt = Date(raw, fmt)
            return string(year(dt))
        catch
            # try the next one
        end
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