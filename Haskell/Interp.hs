module Interp where

import Data.Maybe

import GraphMatch
import GPSyntax
import LabelMatch
import GraphMatch
import Graph
import GPCondition

-- type Subst a b = [(a, b)]
-- type NodeMatches = Subst RuleNodeId HostNodeId
-- type EdgeMatches = Subst RuleEdgeId HostEdgeId
-- data GraphMorphism = GM Environment NodeMatches EdgeMatches

notImplemented = error "Not implemented"

-- getNodeLabelsForMorphism :: HostGraph -> RuleGraph -> GraphMorphism -> [ (HostLabel, RuleLabel) ]
-- getNodeLabelsForMorphism h r m = notImplemented

getNodesForMorphism :: HostGraph -> RuleGraph -> GraphMorphism -> [ ( HostNode, RuleNode ) ]
getNodesForMorphism h r m = notImplemented

getEdgesForMorphism :: HostGraph -> RuleGraph -> GraphMorphism -> [ ( HostEdge, RuleEdge ) ]
getEdgesForMorphism h r m = notImplemented



checkAtomsFor :: HostGraph -> RuleGraph -> GraphMorphism -> Bool
checkAtomsFor h g m = notImplemented





-- Filter out any graph morphisms for which RuleGraph conditions are not met
checkAtoms :: HostGraph -> RuleGraph -> [GraphMorphism] -> [GraphMorphism]
checkAtoms h r ms = ms'
    where
        ms' = filter ( checkAtomsFor h r ) ms


nodeEval :: GraphMorphism -> HostGraph -> RuleGraph -> RuleNode -> RuleNode
nodeEval m h r rn@(RuleNode name isRoot label) = RuleNode name isRoot $ labelEval m h r label

edgeEval :: GraphMorphism -> HostGraph -> RuleGraph -> RuleEdge -> RuleEdge
edgeEval m h r re@(RuleEdge bidi label) = RuleEdge bidi $ labelEval m h r label

substituteNodes :: GraphMorphism -> RuleGraph -> HostGraph -> (HostNodeId, RuleNodeId) -> HostGraph
substituteNodes m r h (hid, rid)  = nReLabel h hid hn'
    where
        hn' = nodeEval m h r $ fromJust $ nLabel r rid 

substituteEdges :: Environment -> RuleGraph -> HostGraph -> (HostEdgeId, RuleEdgeId) -> HostGraph
substituteEdges m r h (hid, rid) = eReLabel h hid he'
    where
        he' = edgeEval m h r $ fromJust $ eLabel r rid

applyMorphism :: RuleGraph -> HostGraph -> GraphMorphism -> HostGraph
applyMorphism r h (GM env nms ems) = h''
    where
        h'  = foldl (substituteNodes env r) h nms
        h'' = foldl (substituteEdges env r) h' ems
        -- TODO: add and delete nodes

-- GraphTransformation is a GraphMorphism from HostGraph to rhs
-- of Rule, [NodeId] is the list of host graph NodeIds to be
-- deleted, and [RuleNode] is the list of RuleNodes from the RHS
-- to be evaluated and added to the host graph
data GraphTransformation = (GraphMorphism, [NodeId], [NodeId])

lookup' :: [(a, b)] -> a -> b
lookup' xys x = fromJust $ lookup xys x

makeRhsEdgeSubst :: GraphMorphism -> Rule -> NodeMatches -> HostGraph -> (HostGraph, EdgeMatches)
makeRhsEdgeSubst m r s h = (h', ems')
    where
        ems' = zip res insertedHostEdges
        res = allEdges rhs
        (h', insertedHostEdges) = newEdgeList [
            (lookup' s src, lookup' s tgt)
            | re <- res, 
            let Just src = source rhs re,
            let Just tgt = target rhs re  ]
        Rule _ _ (_, rhs) _ _ _ = r

makeRhsNodeSubst :: GraphMorphism -> Rule -> HostGraph -> (HostGraph, NodeMatches)
makeRhsNodeSubst m r h = (h', nms')
    where
        nms' = [ (ri, hi) | (li, ri) <- intr,
                        let Just hi = lookup li nms ]
               ++ zip insertedRhsNodes insertedHostNodes
        (h', insertedHostNodes) = newNodeList (length insertedRhsNodes) h
        insertedRhsNodes  = allNodes rhs \\ map snd intr
        GM env nms ems = m
        Rule _ _ (_, rhs) intr _ _ = r

-- data Rule = Rule RuleName [Variable] (RuleGraph, RuleGraph) 
            -- Interface Condition String

-- no node or edge labels yet!
transform :: GraphMorphism -> Rule -> HostGraph -> Maybe HostGraph
transform m r h = do
    -- we're in the Maybe monad -- gives us "free" handling
    -- of the dangling condition. Yay.
    h' <- rmIsolatedNodeList deletedHostNodes 
           $ rmEdgeList deletedHostEdges
           $ h 
    let (h'', s) = makeRhsNodeSubst m r h'
    let (h''', s') = makeRhsEdgeSubst m r s h''
    return h'''
    where
        deletedHostEdges  = [ heid | leid <- allEdges lhs,
                                     let Just heid = lookup leid ems ]
        deletedHostNodes  = [ hnid | lnid <- deletedLhsNodes,
                                     let Just hnid = lookup lnid nms ]
        deletedLhsNodes   = allNodes lhs \\ map fst intr
        Rule _ _ (lhs, rhs) intr _ _  = r
        GM env nms ems                = m

applyRule :: HostGraph -> Rule -> [HostGraph]
applyRule h (Rule _ _ (lhs, rhs) i cond _) =
        [ h' | m <- matchGraphs h lhs, let Just h' = transform m r h ]

