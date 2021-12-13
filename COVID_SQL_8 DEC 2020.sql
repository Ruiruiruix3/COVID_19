SELECT *
FROM Covid_19..CovidDeaths
WHERE continent IS NULL


SELECT DISTINCT continent
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL


SELECT *
FROM Covid_19..CovidVaccinations


SELECT location, date, total_cases, new_cases, total_deaths, population
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2

--Death percentage if infected with covid
SELECT 
	location, 
	date,
	total_cases,
	total_deaths,
	(total_deaths/total_cases)*100 AS death_percentage	
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2


--Total cases, Population and infection rate till today 8/DEC/2021
SELECT 
	location,
	date,
	total_cases,
	population,
	(total_cases/population)*100 AS infected_rate
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL AND date = 
	(
		SELECT MAX(date)
		FROM Covid_19..CovidDeaths
	)
ORDER BY 5 DESC


--Countries death rate
SELECT 
	location, 
	date, 
	CAST(total_deaths AS int) AS total_death,
	population,
	(CAST(total_deaths AS int)/population)*100 AS death_rate --total death is nvarchar data type
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL AND date = 
	(
		SELECT MAX(date)
		FROM Covid_19..CovidDeaths
	)
ORDER BY 5 DESC


--total case by continent
SELECT 
	continent,
	MAX(CAST(total_cases AS int)) AS total_cases
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY 2 DESC;

--total case rate over population by continent
WITH Continent_country AS
(
SELECT 
	continent,
	location,
	population,
	total_cases,
	SUM(population) OVER (PARTITION BY continent) AS total_pop
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL AND date =
	(
		SELECT MAX(date)
		FROM Covid_19..CovidDeaths
	)
)
SELECT 
	continent,
	MAX(total_cases) AS total_cases_by_continent,
	total_pop,
	(MAX(total_cases)/total_pop)*100 AS infection_rate
FROM Continent_country
GROUP BY continent, total_pop
ORDER BY 4 DESC;


--total death by continent
SELECT 
	continent,
	MAX(CAST(total_deaths AS int)) AS total_death
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY 2 DESC;


--total death rate over population by continent
WITH Continent_country AS
(
SELECT 
	continent,
	location,
	population,
	total_deaths,
	SUM(population) OVER (PARTITION BY continent) AS total_pop
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL AND date =
	(
		SELECT MAX(date)
		FROM Covid_19..CovidDeaths
	)
)
SELECT 
	continent,
	MAX(CAST(total_deaths AS bigint)) AS total_death_by_continent,
	total_pop,
	(MAX(CAST(total_deaths AS bigint))/total_pop)*100 AS death_rate
FROM Continent_country
GROUP BY continent, total_pop
ORDER BY 4 DESC;


--Global numbers view of daily covid cases and daily death rate
SELECT 
	date,
	SUM(new_cases) AS world_new_covid,
	SUM(CAST(new_deaths AS int)) AS world_new_death,
	(SUM(CAST(new_deaths AS int))/ SUM(new_cases))*100 AS world_death_percentage
FROM Covid_19..CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY date
ORDER BY date


--Global view vs global population till 8/Dec/2021
WITH global_pop AS
(
	SELECT 
		date,
		location,
		population,
		total_cases,
		CAST(total_deaths AS int) AS total_deaths_int
	FROM Covid_19..CovidDeaths
	WHERE date = 
		(
			SELECT MAX(date)
			FROM Covid_19..CovidDeaths
		) AND continent IS NOT NULL
)
SELECT 
	date,
	SUM(population) AS world_population,
	SUM(total_cases) AS world_new_case,
	SUM(total_deaths_int) AS world_covid_death,
	(SUM(total_cases)/SUM(population))*100 AS new_cases_per_hundred,
	(SUM(total_deaths_int)/SUM(population))*100 AS dealth_per_hundred
FROM global_pop
GROUP BY date



--new vaccination per day vs population for each country
SELECT 
	d.location,
	d.date,
	population,
	new_vaccinations,
	total_vaccinations
FROM Covid_19..CovidVaccinations v
INNER JOIN Covid_19..CovidDeaths d
	ON v.date = d.date AND v.location = d.location
WHERE d.continent IS NOT NULL
ORDER BY 1,2


--cummulative of new vaccinated
SELECT 
	location,
	date,
	new_vaccinations,
	SUM(CAST(new_vaccinations AS bigint)) OVER
		(PARTITION BY location
			ORDER BY location, date) AS cummulative_vac,
	total_vaccinations
FROM Covid_19..CovidVaccinations
WHERE continent IS NOT NULL
ORDER BY location, date


--Use CTE to get the total vaccination percentage for each country
WITH PopVac (location, total_vac, population) AS
(SELECT
	v.location,
	MAX(CAST(total_vaccinations AS bigint)),
	population
FROM Covid_19..CovidVaccinations v
INNER JOIN Covid_19..CovidDeaths d 
	ON v.date = d.date AND v.location = d.location
WHERE v.continent IS NOT NULL
GROUP BY v.location, population
)
SELECT 
	location, total_vac, population,
	(total_vac/population)*100 AS vaccinated_percentage
FROM PopVac
ORDER BY 4 DESC



--Create a View for the above CTE of total vaccination percentage for each country
CREATE VIEW total_vac_percentage_view AS
WITH PopVac (location, total_vac, population) AS
(SELECT
	v.location,
	MAX(CAST(total_vaccinations AS bigint)),
	population
FROM Covid_19..CovidVaccinations v
INNER JOIN Covid_19..CovidDeaths d 
	ON v.date = d.date AND v.location = d.location
WHERE v.continent IS NOT NULL
GROUP BY v.location, population
)
SELECT 
	location, total_vac, population,
	(total_vac/population)*100 AS vaccinated_percentage
FROM PopVac
--ORDER BY 4 DESC;

SELECT *
FROM total_vac_percentage_view;


--Use Temp table to view total number of boosters taken by each country on daily basis
DROP TABLE IF EXISTS #booster
CREATE TABLE #booster
(
location nvarchar(255),
date datetime,
population float,
total_boosters bigint
)

INSERT INTO #booster
SELECT
	v.location,
	v.date,
	population,
	CAST(total_boosters AS bigint)
FROM Covid_19..CovidVaccinations v
INNER JOIN Covid_19..CovidDeaths d 
	ON v.date = d.date AND v.location = d.location
WHERE v.continent IS NOT NULL

SELECT 
	*
FROM #booster
WHERE total_boosters IS NOT NULL
ORDER BY location, date


--Use the previous created temp table to view the total boosters percentage for each country
SELECT 
	location,
	date,
	population,
	total_boosters,
	(total_boosters/population)*100 AS booster_percentage
FROM #booster
WHERE total_boosters IN
	(
		SELECT MAX(total_boosters)
		FROM #booster
		GROUP BY location
	)
ORDER BY 5 DESC


--total vaccinated by continent
SELECT 
	continent,
	MAX(CAST(total_vaccinations AS bigint)) AS total_vac
FROM Covid_19..CovidVaccinations
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY 2 DESC;

--total vaccination rate by continent
WITH Continent_country AS
(SELECT 
	v.continent,
	v.location,
	total_vaccinations,
	population,
	SUM(population) OVER (PARTITION BY d.continent) AS total_pop
FROM Covid_19..CovidVaccinations v
INNER JOIN Covid_19..CovidDeaths d
	ON v.location = d.location and v.date = d.date
WHERE v.continent IS NOT NULL AND total_vaccinations IN
	(
		SELECT MAX(CAST(total_vaccinations AS bigint))
		FROM Covid_19..CovidVaccinations
		GROUP BY location
	)
)
SELECT 
	continent,
	total_pop,
	MAX(CAST(total_vaccinations AS bigint)) AS total_vac,
	(MAX(CAST(total_vaccinations AS bigint))/total_pop)*100 AS vac_rate
FROM Continent_country
GROUP BY continent, total_pop
ORDER BY 4 DESC;


--Global view(population, new case, death, vaccine) global population till 8/Dec/2021
WITH global_pop AS
(
SELECT 
	date,
	location,
	population,
	total_cases,
	CAST(total_deaths AS bigint) AS total_deaths_int
FROM Covid_19..CovidDeaths 
WHERE date = 
	(
		SELECT MAX(date)
		FROM Covid_19..CovidDeaths
	) AND continent IS NOT NULL
),
country_max_vac AS
(
SELECT 
	location,
	MAX(CAST(total_vaccinations AS bigint)) AS total_vac
FROM Covid_19..CovidVaccinations
GROUP BY location
)
SELECT 
	date,
	SUM(population) AS world_population,
	SUM(total_cases) AS world_new_case,
	SUM(total_deaths_int) AS world_covid_death,
	SUM(total_vac) AS world_total_vaccination,
	(SUM(total_cases)/SUM(population))*100 AS new_cases_per_hundred,
	(SUM(total_deaths_int)/SUM(population))*100 AS dealth_per_hundred,
	(SUM(total_vac)/SUM(population))*100 AS vaccination_per_hundred
FROM global_pop p
INNER JOIN country_max_vac cmv
	ON p.location = cmv.location
GROUP BY date;





