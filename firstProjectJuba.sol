// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol" ;

contract Voting is Ownable {

    uint public winningProposalId ;
    uint numberOfProposals ; // cette uint sera utilisé uniquement pr un but pratique dans "reinitiliaze"
    uint disputingWinnersNum ; // cette uint sera utilisé uniquement pr un but pratique dans "reintiliaze"

    Proposal[] public proposals ; 
    Proposal[] public disputingWinners ; // cette array va stocker les vainqueurs qui se disputent
    Proposal[] public winnersHistory ; // cette array va stocker toutes les propositions qui ont gagné dans l'histoire
    address[] participants ;

    struct Voter {
        bool isRegistred ;
        bool hasVoted ;
        uint votedProposalId ;
    }

    struct Proposal {
        string description ;
        uint voteCount ;
    }

    mapping (address => Voter) public votersMapping ;

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus public workflowStatus = WorkflowStatus.RegisteringVoters ;

    // below we set all the necessary modifiers to check the workflow status when the owner (administrator) or when the voters do call them

    modifier duringProposalsRegistration() {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, 
           "the function can be called after the proposals registration session opened and during it");
       _;
    }
    
    modifier afterProposalsRegistration() {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded,  
           "this function can be called after the proposals registration session is closed");
       _;
    }
    
    modifier duringVotingSession() {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, 
           "the function can be called after the voting session started and during it");
       _;
    }
    
    modifier afterVotingSession() {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded,  
           "this function can be called after the voting session is closed");
       _;
    }

    modifier Whitelisted () {
        require (votersMapping[msg.sender].isRegistred == true, "you aren't registred") ;
        _;
    }

    function whitelistAddr (address _address) public onlyOwner {
        require (votersMapping[_address].isRegistred == false, "voter is already whitelisted") ;
        votersMapping[_address].isRegistred = true ;
        participants.push(_address);
        emit VoterRegistered(_address) ;
    }

    function startRegistrationSession () public onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted ;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, workflowStatus) ;
    }

    function makeAProposal (string memory _proposal) public Whitelisted duringProposalsRegistration {
        require (keccak256(abi.encodePacked(_proposal)) != keccak256(abi.encodePacked("")),
        "your proposal can't be empty") ;
        Proposal memory newPropal = Proposal (_proposal, 0) ;
        proposals.push(newPropal) ;
        numberOfProposals ++ ;
        emit ProposalRegistered (numberOfProposals - 1) ;
    }

    function endRegistrationSession () public onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded ;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, workflowStatus) ;
    }

    function startVotingSession () public onlyOwner {
        workflowStatus = WorkflowStatus.VotingSessionStarted ;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, workflowStatus) ;
    }

    function vote (uint proposalIdx) public Whitelisted duringVotingSession{
        require (proposalIdx < proposals.length, "this proposal doesn't exist") ;
        require (votersMapping[msg.sender].hasVoted == false, "you already voted") ;
        votersMapping[msg.sender].hasVoted = true ;
        votersMapping[msg.sender].votedProposalId = proposalIdx ;
        proposals[proposalIdx].voteCount ++ ;
        emit VoterRegistered(msg.sender) ;
    }

    function endVotingSession () public onlyOwner {
        workflowStatus = WorkflowStatus.VotingSessionEnded ;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, workflowStatus) ;
    }

    function determineWinner () public onlyOwner afterVotingSession returns (string memory) {
        uint max = proposals[0].voteCount ;
        for (uint i = 0 ; i < proposals.length ; i ++){
            if (proposals[i].voteCount > max) {
                max = proposals[i].voteCount ;
                winningProposalId = i ;
            }
        }
        // la partie en dessous traite 2 (ou +) propals gagnantes 
        for (uint i = 0 ; i < proposals.length ; i ++){
            // si la condition en dessous est satisfaite ==> il y a au moins 2 propals gagnantes
            if (proposals[i].voteCount == max && i != winningProposalId) {
                disputingWinners.push(proposals[i]) ;
                disputingWinnersNum ++ ;
            }
        }
        // si disputingWinner.length = 0, ça veut dire qu'on a qu'un seul gagnant
        if (disputingWinners.length == 0) {
            winnersHistory.push(proposals[winningProposalId]) ;
            return proposals[winningProposalId].description ;
        }
        // sinon ça veut dire qu'on en a plusieurs et c'est à ce moment là que les fonctions ci-dessous auront de l'intérêt
        else {
            disputingWinners.push(proposals[winningProposalId]) ;
            return "there is more than one winner. A vote must be reconducted with the winners ONLY. Check disputingWinners array or proposals array" ;
        }
        workflowStatus = WorkflowStatus.VotesTallied ;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, workflowStatus) ;
    }

    // les fonctions reinitiliaze va réinialiser les values de toutes les keys des "Voter"
    // pourquoi ? pour recommencer un vote en cas d'égalité ou recommencer un nouveau vote
    // nous allons séparer la fonction reinitiliaze en 2 car on ne peut disputingWinners.pop
    // dans la même fonction, sinon on ne peut remplacer les éléments dans proposals par ceux
    // dans disputingWinners

    // attention à bien executer reinitiliazeProposals en premier puis ensuite reinitiliazeDisputingWinners.

    function reinitializeProposals () public onlyOwner {
        for (uint i = 0 ; i < participants.length ; i++){
            votersMapping[participants[i]].hasVoted = false ;
            // mieu de reset votedProposalId à 1000 plutôt qu'à 0, on comprend mieux que l'utilisateur n'a pas encore voté / revoté
            votersMapping[participants[i]].votedProposalId = 1000 ;
        }
        // on enlève tout à l'intérieur de proposals SI il n'y a pas différents gagnants. Si il y a différents gagnants, on enlève tout puis 
        // on insert les éléments qui sont dans disputingWinners. Le nouveau "proposals" va servir pour le prochain vote, les utilisateurs 
        // ne pourront voter que pour les propositions gagnantes du tour d'avant. On reset numberOfProposals à 0 si il n'y a pas de deuxième tout,
        // cependant si il y a différents propositions gagnantes, on le reset au nombre de propositions du 2nd tour.
        delete proposals ;
        if (disputingWinners.length != 0){
            for (uint i = 0 ; i < disputingWinners.length ; i++){
                proposals.push(disputingWinners[i]) ;
                proposals[i].voteCount = 0 ;
            }
            numberOfProposals = disputingWinners.length ;
        }
        else {
            numberOfProposals = 0 ;
        }
        // on modifie le workflow à la fin, et ensuite on peut passer au tour suivant 
        workflowStatus = WorkflowStatus.RegisteringVoters ;
        emit WorkflowStatusChange(WorkflowStatus.VotesTallied, workflowStatus) ;      
    }

    // on reintiliaze disputingWinners pour le prochain tour (ou prochaine session).
    function reinitializeDisputingWinners () public onlyOwner {
        delete disputingWinners ;
        disputingWinnersNum = 0 ;
    }

}