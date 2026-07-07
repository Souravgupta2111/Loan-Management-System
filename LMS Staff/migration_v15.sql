-- migration_v15.sql
-- Adds tables for AI conversations and credit score history

-- AI Conversation sessions
CREATE TABLE ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('borrower', 'officer', 'manager')),
    title TEXT,                              -- auto-generated from first message
    context_ref_id UUID,                     -- optional: application_id for officer context
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Individual messages in a conversation
CREATE TABLE ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    suggested_actions JSONB,                 -- optional action buttons
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Credit score history tracking
CREATE TABLE credit_score_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    score INT NOT NULL,
    bureau TEXT,
    recorded_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_ai_conversations_user ON ai_conversations(user_id);
CREATE INDEX idx_ai_messages_conversation ON ai_messages(conversation_id);
CREATE INDEX idx_credit_score_history_user ON credit_score_history(user_id);

-- RLS Policies
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_score_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own conversations"
    ON ai_conversations FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own messages"
    ON ai_messages FOR ALL USING (
        conversation_id IN (SELECT id FROM ai_conversations WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can view own credit history"
    ON credit_score_history FOR SELECT USING (auth.uid() = user_id);
