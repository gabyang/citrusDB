psql -U postgres -d postgres < schema.sql
psql -U postgres -d postgres -c "\\copy companies from 'companies.csv' with csv"
psql -U postgres -d postgres -c "\\copy campaigns from 'campaigns.csv' with csv"
psql -U postgres -d postgres -c "\\copy ads from 'ads.csv' with csv"
psql -U postgres -d postgres -c "\\copy clicks from 'clicks.csv' with csv"
psql -U postgres -d postgres -c "\\copy impressions from 'impressions.csv' with csv"
