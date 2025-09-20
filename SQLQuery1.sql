use [INDIA ELECTIONS RESULT] 

SELECT * FROM dbo.constituencywise_details                      

SELECT * FROM dbo.constituencywise_results

SELECT * FROM dbo.partywise_results

SELECT * FROM dbo.states

SELECT * FROM dbo.statewise_results
--------------------

ALTER TABLE partywise_results
ADD party_alliance VARCHAR(50);


---I.N.D.I.A Allianz
UPDATE partywise_results
SET party_alliance = 'I.N.D.I.A'
WHERE party IN (
    'Indian National Congress - INC',
    'Aam Aadmi Party - AAAP',
    'All India Trinamool Congress - AITC',
    'Bharat Adivasi Party - BHRTADVSIP',
    'Communist Party of India  (Marxist) - CPI(M)',
    'Communist Party of India  (Marxist-Leninist)  (Liberation) - CPI(ML)(L)',
    'Communist Party of India - CPI',
    'Dravida Munnetra Kazhagam - DMK',	
    'Indian Union Muslim League - IUML',
    'Jammu & Kashmir National Conference - JKN',
    'Jharkhand Mukti Morcha - JMM',
    'Kerala Congress - KEC',
    'Marumalarchi Dravida Munnetra Kazhagam - MDMK',
    'Nationalist Congress Party Sharadchandra Pawar - NCPSP',
    'Rashtriya Janata Dal - RJD',
    'Rashtriya Loktantrik Party - RLTP',
    'Revolutionary Socialist Party - RSP',
    'Samajwadi Party - SP',
    'Shiv Sena (Uddhav Balasaheb Thackrey) - SHSUBT',
    'Viduthalai Chiruthaigal Katchi - VCK'
);
----NDA Allianz
UPDATE partywise_results
SET party_alliance = 'NDA'
WHERE party IN (
    'Bharatiya Janata Party - BJP',
    'Telugu Desam - TDP',
    'Janata Dal  (United) - JD(U)',
    'Shiv Sena - SHS',
    'AJSU Party - AJSUP',
    'Apna Dal (Soneylal) - ADAL',
    'Asom Gana Parishad - AGP',
    'Hindustani Awam Morcha (Secular) - HAMS',
    'Janasena Party - JnP',
    'Janata Dal  (Secular) - JD(S)',
    'Lok Janshakti Party(Ram Vilas) - LJPRV',
    'Nationalist Congress Party - NCP',
    'Rashtriya Lok Dal - RLD',
    'Sikkim Krantikari Morcha - SKM'
);
----OTHER
UPDATE partywise_results
SET party_alliance = 'OTHER'
WHERE party_alliance IS NULL;
-------------------------------------------------------------------------------------------------------------------------------------


----------------------------------------------  CREATE VIEWS ------------------------------------------------------------------------
CREATE VIEW vw_constituency_analysis AS
SELECT 
    cd.Candidate,
    cd.Party,
    cd.EVM_Votes,
    cd.Postal_Votes,
    cd.Total_Votes,
    cd.Constituency_ID,
    cr.Parliament_Constituency,
    cr.Constituency_Name,
    cr.Winning_Candidate,
    cr.Margin,
    sr.State,
    sr.State_ID, 
    pr.party_alliance,
    RANK() OVER (PARTITION BY cd.Constituency_ID ORDER BY cd.Total_Votes DESC) as Position
FROM constituencywise_details cd 
JOIN constituencywise_results cr 
    ON cd.Constituency_ID = cr.Constituency_ID
JOIN partywise_results pr 
    ON cr.Party_ID = pr.Party_ID
JOIN statewise_results sr 
    ON cr.Parliament_Constituency = sr.Parliament_Constituency;

SELECT * FROM vw_constituency_analysis
--------------------

CREATE VIEW vw_state_alliance_analysis AS
SELECT
    sr.State,
    sr.State_ID, 
	sr.Region,
    pr.party_alliance,
    COUNT(*) as Seats_Won,
    SUM(cd.EVM_Votes) as Total_EVM_Votes,
    SUM(cd.Postal_Votes) as Total_Postal_Votes,
    SUM(cd.Total_Votes) as Total_Votes_Alliance
FROM constituencywise_details cd 
JOIN constituencywise_results cr 
    ON cd.Constituency_ID = cr.Constituency_ID
JOIN partywise_results pr 
    ON cr.Party_ID = pr.Party_ID
JOIN statewise_results sr 
    ON cr.Parliament_Constituency = sr.Parliament_Constituency
WHERE 
	cd.Candidate = cr.Winning_Candidate
GROUP BY sr.State, sr.State_ID, sr.Region, pr.party_alliance;

SELECT * FROM vw_state_alliance_analysis

--------------------

CREATE VIEW vw_alliance_summary AS
SELECT 
    party_alliance,
    COUNT(*) as Total_Seats_Won,
    SUM(Total_Votes) as Total_Votes_Alliance,
    SUM(Total_Votes - Margin) as Total_Runnerup_Votes,
    SUM(Margin) as Total_Win_Margin,
    ROUND(AVG(Margin), 0) as Avg_Win_Margin,
    COUNT(DISTINCT Party) as Number_of_Parties,
    ROUND((COUNT(*) * 100.0 / 543), 2) as Win_Percentage
FROM vw_constituency_analysis
WHERE Position = 1
GROUP BY party_alliance
ORDER BY Total_Seats_Won DESC;

SELECT * FROM vw_alliance_summary;

-------------------------------------------------------------------------------------------------------------------------------------



                                               ------- 1: National Overview  -----

--- How many total seats are in the Indian Parliament (Lok Sabha) and how many seats are needed for a majority?
SELECT 
    COUNT(DISTINCT Constituency_ID) AS Total_Seats,
    CEILING(COUNT(DISTINCT Constituency_ID) / 2.0) AS Seats_Needed_For_Majority
FROM vw_constituency_analysis;


--- What was the final seat distribution among the major political alliances (NDA, INDIA, and Others)?
SELECT 
	party_alliance,
	Total_Seats_Won
FROM vw_alliance_summary
ORDER BY Total_Seats_Won DESC;


--- Was the winning margin in the 2024 elections a decisive victory or a close contest?
SELECT 
	party_alliance,
	Avg_Win_Margin
FROM vw_alliance_summary
ORDER BY Avg_Win_Margin DESC;

-------------------------------------------------------------------------------------------------------------------------------------



                                                -------  2: State Level   -------


--- What are the top 5 states with the most seats?
SELECT TOP 5
	State,
	SUM(Seats_Won) AS Total_Seats_Won
FROM vw_state_alliance_analysis
GROUP BY State
ORDER BY Total_Seats_Won DESC;


--- Which alliance dominates Northern India or Western India?
SELECT
	party_alliance,
	Region,
	SUM(Seats_Won) AS Total_Seats_Won
FROM vw_state_alliance_analysis
WHERE Region = 'North India' OR Region = 'West India'
GROUP BY party_alliance , Region
ORDER BY Total_Seats_Won DESC;


--- Are there "safe" states for a specific alliance, defined as winning more than 85% of the total seats in that state?
WITH seat_share AS (
    SELECT
        State,
        party_alliance,
        SUM(Seats_Won) AS Total_Seats_Won,
        CAST(
            ROUND(
                (SUM(Seats_Won) * 100.0) / 
                SUM(SUM(Seats_Won)) OVER (PARTITION BY State), 
                2
            ) AS DECIMAL(5,2)
        ) AS Seat_Share_Percentage
    FROM vw_state_alliance_analysis
    GROUP BY State, party_alliance
)
SELECT *
FROM seat_share
WHERE Seat_Share_Percentage > 85
ORDER BY State, Seat_Share_Percentage DESC;

-------------------------------------------------------------------------------------------------------------------------------------


                                         -------  3: Battleground Analysis   -------


--- Where were the closest battles? (Margin < 5000 votes)
SELECT
	State,
	COUNT(Margin) AS Total_Close_Battles
FROM vw_constituency_analysis
WHERE Margin < 5000
GROUP BY State
ORDER BY Total_Close_Battles DESC;


--- Who are the top runner-ups in the close battles?
SELECT 
	Candidate
FROM vw_constituency_analysis
WHERE Margin < 5000  AND Position = 2


--- Which alliance most frequently came in second in close battles (Margin < 5000)?
SELECT 
    party_alliance,
    COUNT(*) AS Number_of_Close_Losses
FROM vw_constituency_analysis
WHERE Margin < 5000 AND Position = 2
GROUP BY party_alliance
ORDER BY Number_of_Close_Losses DESC;


--- Who got the highest individual votes nationwide?
SELECT TOP 1
	Candidate,
	Total_Votes
FROM vw_constituency_analysis
ORDER BY Total_Votes DESC   


-------------------------------------------------------------------------------------------------------------------------------------


                                      -------  4: UP vs Maharashtra   -------

---  How did the main alliances perform in UP vs. Maharashtra?
SELECT 
	State,
	party_alliance,
	Seats_Won,
	Total_Votes_Alliance
FROM vw_state_alliance_analysis 
WHERE State = 'Maharashtra' OR State = 'Uttar Pradesh'


--- Where were the 5 toughest battles in UP and Maharashtra?
WITH RankedBattles AS (
    SELECT
        Candidate,
        Margin,
        State,
        ROW_NUMBER() OVER(PARTITION BY State ORDER BY Margin ASC) as RankNum
    FROM vw_constituency_analysis
    WHERE State IN ('Maharashtra', 'Uttar Pradesh') AND Position = 1
)
SELECT
    Candidate,
    Margin,
    State
FROM RankedBattles
WHERE RankNum <= 5
ORDER BY State, Margin;


--- What is the average winning margin for each alliance in UP compared to Maharashtra?
SELECT 
	State,
	party_alliance,
	AVG(Margin) AS Average_winning_margin
FROM vw_constituency_analysis 
WHERE State = 'Maharashtra' OR State = 'Uttar Pradesh'
GROUP BY State, party_alliance
ORDER BY party_alliance

-------------------------------------------------------------------------------------------------------------------------------------


                                      -------   5: Vote Analysis   -------

--- What is the distribution of EVM vs Postal Votes for winning candidates?
SELECT
	SUM(EVM_Votes) AS Total_EVM_Votes_for_winning_candidates,
	SUM(Postal_Votes) AS Total_Postal_Votes_for_winning_candidates
FROM vw_constituency_analysis
WHERE Candidate = Winning_Candidate 


--- Did any alliance get a much higher percentage of seats than their total national vote percentage?
WITH national_totals AS (
    SELECT
        SUM(Total_Seats_Won) AS Total_Seats,
        SUM(Total_Votes_Alliance) AS Total_Votes
    FROM vw_alliance_summary
)
SELECT
    party_alliance,
    ROUND((CAST(Total_Seats_Won AS FLOAT) / national_totals.Total_Seats) * 100 ,2) AS Seat_Percentage,
    ROUND((CAST(Total_Votes_Alliance AS FLOAT) / national_totals.Total_Votes) * 100, 2) AS Vote_Percentage
FROM
    vw_alliance_summary, national_totals;


--- What are the constituencies with the highest number of voters?
SELECT  TOP 5
	Constituency_Name,
	Total_Votes
FROM vw_constituency_analysis
ORDER BY Total_Votes DESC;


--- How many votes did each alliance need to win a single seat? (Vote-to-Seat Efficiency)
SELECT
    party_alliance,
    Total_Votes_Alliance,
    Total_Seats_Won,
    CASE 
        WHEN Total_Seats_Won > 0 THEN ROUND(CAST(Total_Votes_Alliance AS FLOAT) / Total_Seats_Won, 0)
        ELSE 0 
    END AS Votes_Per_Seat
FROM vw_alliance_summary
WHERE Total_Seats_Won > 0
ORDER BY Votes_Per_Seat ASC;