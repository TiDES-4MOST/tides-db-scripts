-- Add results_file column to pipeline_classification_snid table
-- This column stores the path to the SNID HDF5 results file

DO $$
BEGIN
    -- Add results_file column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'pipeline_classification_snid'
        AND column_name = 'results_file'
    ) THEN
        ALTER TABLE pipeline_classification_snid
        ADD COLUMN results_file TEXT;
        
        RAISE NOTICE 'Added results_file column to pipeline_classification_snid';
    ELSE
        RAISE NOTICE 'results_file column already exists in pipeline_classification_snid';
    END IF;
END $$;
