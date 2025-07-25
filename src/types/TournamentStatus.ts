export enum TournamentStatus {
  DRAFT = 'draft',
  SETUP_COMPLETE = 'setup_complete',
  READY_FOR_REGISTRATION = 'ready_for_registration',
  WAITING_LIST_OPEN = 'waiting_list_open',
  REGISTRATION_OPEN = 'registration_open',
  REGISTRATION_CLOSED = 'registration_closed',
  DRAWS_COMPLETE = 'draws_complete',
  LIVE = 'live',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled'
}

export enum RegistrationType {
  ONLINE_FORM = 'online_form',    // Players register through the online form
  MANUAL_ONLY = 'manual_only',    // Only organizers can add players
  HYBRID = 'hybrid'               // Both online registration and manual entry allowed
}

// Define which status transitions are allowed
export const allowedStatusTransitions: Record<TournamentStatus, TournamentStatus[]> = {
  [TournamentStatus.DRAFT]: [
    TournamentStatus.SETUP_COMPLETE,
    TournamentStatus.CANCELLED
  ],
  [TournamentStatus.SETUP_COMPLETE]: [
    TournamentStatus.READY_FOR_REGISTRATION,
    TournamentStatus.CANCELLED,
    TournamentStatus.DRAFT // Allow going back to draft if changes needed
  ],
  [TournamentStatus.READY_FOR_REGISTRATION]: [
    TournamentStatus.REGISTRATION_OPEN,
    TournamentStatus.SETUP_COMPLETE, // Allow going back if changes needed
    TournamentStatus.CANCELLED
  ],
  [TournamentStatus.WAITING_LIST_OPEN]: [
    TournamentStatus.REGISTRATION_OPEN,
    TournamentStatus.READY_FOR_REGISTRATION,
    TournamentStatus.CANCELLED
  ],
  [TournamentStatus.REGISTRATION_OPEN]: [
    TournamentStatus.REGISTRATION_CLOSED,
    TournamentStatus.CANCELLED
  ],
  [TournamentStatus.REGISTRATION_CLOSED]: [
    TournamentStatus.DRAWS_COMPLETE,
    TournamentStatus.REGISTRATION_OPEN,
    TournamentStatus.CANCELLED
  ],
  [TournamentStatus.DRAWS_COMPLETE]: [
    TournamentStatus.LIVE,
    TournamentStatus.CANCELLED
  ],
  [TournamentStatus.LIVE]: [
    TournamentStatus.COMPLETED,
    TournamentStatus.CANCELLED
  ],
  [TournamentStatus.COMPLETED]: [], // Final state
  [TournamentStatus.CANCELLED]: []  // Final state
};

// Define required components for each status transition
export const statusRequirements: Record<TournamentStatus, string[]> = {
  [TournamentStatus.DRAFT]: [],
  [TournamentStatus.SETUP_COMPLETE]: [
    'Basic tournament information (name, venue)',
    'Start and end dates defined',
    'Tournament rules document',
    'At least one category defined'
  ],
  [TournamentStatus.READY_FOR_REGISTRATION]: [
    'All setup complete requirements met',
    'Registration form configured with:',
    '- Registration deadline set',
    '- Maximum participants per category defined',
    '- Registration type selected (online/manual/hybrid)',
    '- Required player information fields configured'
  ],
  [TournamentStatus.WAITING_LIST_OPEN]: [
    'Ready for registration',
    'Waiting list enabled'
  ],
  [TournamentStatus.REGISTRATION_OPEN]: [
    'Ready for registration',
    'Registration officially launched'
  ],
  [TournamentStatus.REGISTRATION_CLOSED]: [
    'Registration deadline reached'
  ],
  [TournamentStatus.DRAWS_COMPLETE]: [
    'All brackets/groups created',
    'Match schedule generated'
  ],
  [TournamentStatus.LIVE]: [
    'Tournament start date reached'
  ],
  [TournamentStatus.COMPLETED]: [
    'All matches completed',
    'Final results recorded'
  ],
  [TournamentStatus.CANCELLED]: []
};

// Helper function to check if a status transition is allowed
export function canTransitionTo(currentStatus: TournamentStatus, newStatus: TournamentStatus): boolean {
  return allowedStatusTransitions[currentStatus].includes(newStatus);
}

// Helper function to get available next statuses
export function getAvailableNextStatuses(currentStatus: TournamentStatus): TournamentStatus[] {
  return allowedStatusTransitions[currentStatus];
}

// Helper function to get requirements for transitioning to a status
export function getRequirementsForStatus(status: TournamentStatus): string[] {
  return statusRequirements[status];
}

// Function to determine if a registration is allowed
export function isRegistrationAllowed(
  status: TournamentStatus,
  registrationType: RegistrationType
): boolean {
  if (status !== TournamentStatus.REGISTRATION_OPEN) {
    return false;
  }
  
  return registrationType === RegistrationType.ONLINE_FORM || 
         registrationType === RegistrationType.HYBRID;
}

// Function to determine if waiting list registration is allowed
export function isWaitingListAllowed(
  status: TournamentStatus
): boolean {
  return status === TournamentStatus.WAITING_LIST_OPEN;
}

// Function to determine if manual player entry is allowed
export function isManualEntryAllowed(
  status: TournamentStatus,
  registrationType: RegistrationType
): boolean {
  if (status === TournamentStatus.CANCELLED || 
      status === TournamentStatus.COMPLETED ||
      status === TournamentStatus.LIVE) {
    return false;
  }
  
  return registrationType === RegistrationType.MANUAL_ONLY || 
         registrationType === RegistrationType.HYBRID;
} 