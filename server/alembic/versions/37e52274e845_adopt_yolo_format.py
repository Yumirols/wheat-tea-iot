"""adopt_yolo_format

Revision ID: 37e52274e845
Revises: 
Create Date: 2026-07-03 21:35:58.017516
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '37e52274e845'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Rename column confidence to max_conf
    op.alter_column('disease_records', 'confidence', new_column_name='max_conf')
    # Add columns object_number and all_object
    op.add_column('disease_records', sa.Column('object_number', sa.SmallInteger(), nullable=True))
    op.add_column('disease_records', sa.Column('all_object', sa.JSON(), nullable=True))


def downgrade() -> None:
    # Drop columns all_object and object_number
    op.drop_column('disease_records', 'all_object')
    op.drop_column('disease_records', 'object_number')
    # Rename column max_conf back to confidence
    op.alter_column('disease_records', 'max_conf', new_column_name='confidence')
