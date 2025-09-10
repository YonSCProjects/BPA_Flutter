/**
 * Migration Configuration for Educators Collection
 * 
 * Controls whether to use the legacy 'educators' collection
 * or the new unified 'users' collection with role='educator'
 */

export const MigrationConfig = {
  /**
   * When true: Uses legacy 'educators' collection (current state)
   * When false: Uses 'users' collection with role='educator' filter (target state)
   */
  useLegacyEducatorsCollection: false,
  
  /**
   * Helper to get the collection name based on the flag
   */
  getEducatorsCollection: () => {
    return MigrationConfig.useLegacyEducatorsCollection ? 'educators' : 'users';
  },
  
  /**
   * Helper to build the query constraints for educators
   */
  getEducatorQueryConstraints: () => {
    if (MigrationConfig.useLegacyEducatorsCollection) {
      // For educators collection, we might filter by active
      return [];
    } else {
      // For users collection, we need to filter by role
      return ['role', '==', 'educator'];
    }
  }
};

export default MigrationConfig;