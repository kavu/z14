pragma solidity ^0.4.11;

interface ValidatorSet {
  event ValidatorsChanged(bytes32 _parent_hash, uint256 _nonce, address[] _new_set);

  function getValidators() constant returns (address[] validators);
  function transitionNonce() constant returns (uint256);
}

contract VotedAdmins is ValidatorSet {
  struct User {
    address id;
    string name;
    bool isAdmin;
  }

  struct Voting {
    address id;
    string name;
    uint minDeadline;
    uint maxDeadline;
    address[] voters;
  }

  // Events
  event VotingCreated(address id,
                      string name,
                      uint minVotingDays,
                      uint maxVotingDays);

  event UserVoted(address adminId,
                  string adminName,
                  address candidateId,
                  string candidateName);

  event VotingCompleted(address id,
                        string name,
                        uint votes);

  event UserApproved(address id,
                    string name);

  event UserRejected(address id,
                    string name);

  // Helper Events
  event log_uint(string name, uint value);
  event log_bool(string name, bool value);

  // Constants
  address private _initialAdminId = 0x007CcfFb7916F37F7AEEf05E8096ecFbe55AFc2f;
  string  private constant _initialAdminName = "root";

  // Current Active Votes, per Address
  mapping(address => bool) private _currentVotings; // What is default value?

  // Current Admins, per Address
  mapping(address => bool) private _isAdmin; // What is default value?

  uint256 private _adminsCount;
  uint8   private _needVotingPercent;
  uint256 private _minVotingDays;
  uint256 private _maxVotingDays;

  mapping(address => User)   public  users;
  mapping(address => Voting) private votings;

  // Constructor
  function VotedAdmins(uint8 _min_days, uint8 _max_days, uint8 _percent) {
    require(_min_days >= 0 );
    _minVotingDays = _min_days;

    require(_max_days >= 0 );
    _maxVotingDays = _max_days;

    require(_max_days > _min_days);

    require(_percent >= 0 && _percent <= 100);
    _needVotingPercent = _percent;

    User memory initialAdmin = User({
      id: _initialAdminId,
      name: _initialAdminName,
      isAdmin: false
    });

    addUser(initialAdmin);
    setAdmin(initialAdmin);
  }

  // Users Manipulation
  function addUser(User _user) private {
    users[_user.id] = _user;
  }

  function setAdmin(User _user) private {
    users[_user.id].isAdmin = true;
    _isAdmin[_user.id] = true;
    _validatorsList.push(_user.id);
    _adminsCount += 1;
    adminsChanged();
  }

  // Voting
  function addCandidate(address _id, string _name) {
    require(msg.sender != _id);   // Cannot nominate itself!

    // Check if Address is already Validator
    for (var i = 0; i < _validatorsList.length; i++) {
      address _validator = _validatorsList[i];

      if (_id == _validator) { throw; }
    }

    address[] memory _voters;

    var _voting = Voting({
      id: _id,
      name: _name,
      minDeadline: now + _minVotingDays * 1 days,
      maxDeadline: now + _maxVotingDays * 1 days,
      voters: _voters,
    });

    votings[_id] = _voting;
    _currentVotings[_id] = true;

    VotingCreated(_id, _name, _minVotingDays, _maxVotingDays);
  }

  function voteCandidate(address _id) adminOnly {
    // Check if Sender already voted
    for (var i = 0; i < votings[_id].voters.length; i++) {
      address _voter = votings[_id].voters[i];

      if (msg.sender == _voter) { throw; }
    }

    if (now < votings[_id].maxDeadline) {
      votings[_id].voters.push(_id);
    }

    UserVoted(users[msg.sender].id,
              users[msg.sender].name,
              votings[_id].id,
              votings[_id].name);

    checkVoting(_id);
  }

  function checkVoting(address _id) adminOnly {
    if (checkVotesFor(votings[_id])) {
      endVoting(_id, true);
      return;
    }

    if (now >= votings[_id].minDeadline && checkVotesFor(votings[_id])) {
      endVoting(_id, true);
      return;
    }

    if (now >= votings[_id].maxDeadline && !checkVotesFor(votings[_id])) {
      endVoting(_id, false);
    }
  }

  function endVoting(address _id, bool _makeAdmin) private {
    if (_makeAdmin) {
      User memory user = User({
        id: votings[_id].id,
        name: votings[_id].name,
        isAdmin: false
      });

      addUser(user);
      setAdmin(user);

      UserApproved(votings[_id].id, votings[_id].name);
    } else {
      UserRejected(votings[_id].id, votings[_id].name);
    }

    VotingCompleted(votings[_id].id,
                    votings[_id].name,
                    votings[_id].voters.length);

    delete _currentVotings[_id];
    delete votings[_id];
  }

  function checkVotesFor(Voting _voting) private constant returns (bool) {
    return (_voting.voters.length / _adminsCount) * 100 >= _needVotingPercent;
  }

  // Logging Function
  function adminsChanged() private {
    _transitionNonce += 1;
    ValidatorsChanged(block.blockhash(block.number - 1),
                      _transitionNonce,
                      _validatorsList);
  }

  // ValidatorSet implementation
  uint256 private _transitionNonce;
  address[] private _validatorsList;

  function getValidators() constant returns (address[]) {
    return _validatorsList;
  }

  function transitionNonce() constant returns (uint256) {
    return _transitionNonce;
  }

  // Modifiers
  modifier adminOnly() {
    require(_isAdmin[msg.sender]);
    _;
  }

  // Payable Fallback
  function() payable {
    throw;
  }
}
