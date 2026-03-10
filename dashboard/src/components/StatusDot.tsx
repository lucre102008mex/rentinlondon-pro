type Status = 'active' | 'pending' | 'error' | 'idle';

const StatusDot = ({ status, className = '' }: { status: Status; className?: string }) => (
  <span className={`status-dot status-${status} ${className}`} />
);

export default StatusDot;
